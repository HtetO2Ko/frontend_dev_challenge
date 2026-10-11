import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../model/cart_item_model.dart';
import '../model/deal_model.dart';
import '../repository/order_repo.dart';
import '../service/api_exception.dart';
import '../util/log_service.dart';

/// App-wide cart. Lives for the whole session.
class CartService extends GetxService {
  final OrderRepo orderRepo;
  CartService({required this.orderRepo});

  final items = <CartItemModel>[].obs;
  final itemCount = 0.obs;
  Timer? _ticker;

  @override
  void onInit() {
    super.onInit();
    // Ticker to update countdowns and check for expired reservations every second
    _ticker =
        Timer.periodic(const Duration(seconds: 1), (_) => _checkExpirations());
  }

  @override
  void onClose() {
    _ticker?.cancel();
    super.onClose();
  }

  void _checkExpirations() {
    final now = DateTime.now().toUtc();
    bool changed = false;
    for (final item in items.toList()) {
      final res = item.reservation;
      if (res != null && now.isAfter(res.expiresAt)) {
        LogService.log('Reservation expired for deal ${item.deal.id}');
        items.remove(item);
        changed = true;
        Get.snackbar(
          'Reservation expired',
          'Your hold for "${item.deal.name}" expired and was removed.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.black87,
          colorText: Colors.white,
        );
      }
    }
    if (changed) _recount();
  }

  bool isExpired(DealModel deal) {
    final endsAt = deal.flashSaleEndsAt;
    return endsAt != null && !endsAt.isAfter(DateTime.now());
  }

  Future<void> add(DealModel deal) async {
    if (isExpired(deal)) {
      expireDeal(deal.id, dealName: deal.name);
      return;
    }

    final existing = items.firstWhereOrNull(
      (item) => item.deal.id == deal.id,
    );

    if (existing != null) {
      if (existing.quantity >= deal.quantityLeft && !existing.isReserving) {
        LogService.log('cart: cannot add more of deal ${deal.id}');
        Get.snackbar(
          'Quantity limit reached',
          'No more units are available for this deal.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      // Optimistic update
      existing.quantity++;
      existing.isReserving = true;
      items.refresh();
      _recount();

      try {
        // Release old reservation before requesting a new one with increased quantity
        if (existing.reservation != null) {
          await orderRepo.releaseReservation(existing.reservation!.id);
        }
        final res =
            await orderRepo.reserve(deal.id, quantity: existing.quantity);
        existing.reservation = res;
      } on ApiException catch (e) {
        LogService.error('Failed to reserve increased quantity', e);

        // Explicitly check for 409 Stock Contention / Conflict
        if (e.statusCode == 409) {
          LogService.log('Stock contention detected (409) for deal ${deal.id}');
        }

        // Rollback optimistic quantity increase
        existing.quantity--;
        if (existing.quantity <= 0) {
          items.remove(existing);
        } else {
          // Re-reserve previous valid quantity
          try {
            final res =
                await orderRepo.reserve(deal.id, quantity: existing.quantity);
            existing.reservation = res;
          } catch (_) {}
        }

        Get.snackbar(
          'Could not reserve',
          e.message,
          snackPosition: SnackPosition.BOTTOM,
        );
      } finally {
        existing.isReserving = false;
        items.refresh();
        _recount();
      }
    } else {
      // New item optimistic addition
      final newItem = CartItemModel(deal: deal, quantity: 1, isReserving: true);
      items.add(newItem);
      _recount();

      try {
        final res = await orderRepo.reserve(deal.id, quantity: 1);
        newItem.reservation = res;
      } on ApiException catch (e) {
        LogService.error('Failed to reserve new item', e);

        // Explicitly check for 409 Stock Contention / Conflict
        if (e.statusCode == 409) {
          LogService.log(
              'Stock contention detected (409) on new reservation for deal ${deal.id}');
        }

        // Rollback new item addition
        items.remove(newItem);

        Get.snackbar(
          'Could not reserve',
          e.message,
          snackPosition: SnackPosition.BOTTOM,
        );
      } finally {
        newItem.isReserving = false;
        items.refresh();
        _recount();
      }
    }
  }

  Future<void> expireDeal(int dealId, {String? dealName}) async {
    final index = items.indexWhere((item) => item.deal.id == dealId);
    if (index == -1) return;

    final item = items[index];
    if (item.reservation != null) {
      try {
        await orderRepo.releaseReservation(item.reservation!.id);
      } catch (_) {}
    }

    final name = dealName ?? item.deal.name;
    items.removeAt(index);
    _recount();

    Get.snackbar(
      'Flash sale expired',
      '"$name" has expired and was removed from your bag.',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 4),
      margin: const EdgeInsets.all(12),
      backgroundColor: Colors.black87,
      colorText: Colors.white,
      icon: const Icon(
        Icons.timer_off,
        color: Colors.white,
      ),
    );
  }

  Future<void> decrement(int dealId) async {
    final index = items.indexWhere(
      (item) => item.deal.id == dealId,
    );

    if (index == -1) return;

    final item = items[index];

    if (isExpired(item.deal)) {
      expireDeal(dealId, dealName: item.deal.name);
      return;
    }

    if (item.quantity > 1) {
      item.quantity--;
      items.refresh();
      _recount();

      try {
        if (item.reservation != null) {
          await orderRepo.releaseReservation(item.reservation!.id);
        }
        final res =
            await orderRepo.reserve(item.deal.id, quantity: item.quantity);
        item.reservation = res;
      } catch (e) {
        LogService.error('Error adjusting reservation on decrement', e);
      }
    } else {
      remove(dealId);
    }
  }

  Future<void> remove(int dealId) async {
    final index = items.indexWhere((item) => item.deal.id == dealId);
    if (index != -1) {
      final item = items.removeAt(index);
      if (item.reservation != null) {
        try {
          await orderRepo.releaseReservation(item.reservation!.id);
        } catch (_) {}
      }
      _recount();
    }
  }

  void clear() {
    items.clear();
    _recount();
  }

  num get total => items.fold(
        0,
        (sum, item) => sum + item.lineTotal,
      );

  void _recount() {
    itemCount.value = items.fold(
      0,
      (sum, item) => sum + item.quantity,
    );
  }
}

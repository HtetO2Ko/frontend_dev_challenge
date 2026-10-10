import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../model/cart_item_model.dart';
import '../model/deal_model.dart';
import '../util/log_service.dart';

/// App-wide cart. Lives for the whole session.
class CartService extends GetxService {
  final items = <CartItemModel>[].obs;
  final itemCount = 0.obs;

  bool isExpired(DealModel deal) {
    final endsAt = deal.flashSaleEndsAt;
    return endsAt != null && !endsAt.isAfter(DateTime.now());
  }

  void add(DealModel deal) {
    if (isExpired(deal)) {
      expireDeal(deal.id, dealName: deal.name);
      return;
    }

    final existing = items.firstWhereOrNull(
      (item) => item.deal.id == deal.id,
    );

    if (existing != null) {
      if (existing.quantity >= deal.quantityLeft) {
        LogService.log('cart: cannot add more of deal ${deal.id}');

        Get.snackbar(
          'Quantity limit reached',
          'No more units are available for this deal.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      existing.quantity++;
      items.refresh();
    } else {
      items.add(CartItemModel(deal: deal));
    }

    _recount();
  }

  /// Removes an expired deal and shows a notice only if it was in the cart.
  void expireDeal(int dealId, {String? dealName}) {
    final index = items.indexWhere(
      (item) => item.deal.id == dealId,
    );

    if (index == -1) return;

    final item = items[index];
    final name = dealName ?? item.deal.name;

    items.removeAt(index);
    _recount();

    LogService.log('cart: removed expired deal $dealId');

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

  void decrement(int dealId) {
    final index = items.indexWhere(
      (item) => item.deal.id == dealId,
    );

    if (index == -1) return;

    final item = items[index];

    if (isExpired(item.deal)) {
      expireDeal(dealId, dealName: item.deal.name);
      return;
    }

    item.quantity--;

    if (item.quantity <= 0) {
      items.removeAt(index);
    } else {
      items.refresh();
    }

    _recount();
  }

  void remove(int dealId) {
    items.removeWhere((item) => item.deal.id == dealId);
    _recount();
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
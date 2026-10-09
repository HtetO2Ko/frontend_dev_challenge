import 'package:get/get.dart';

import '../../model/deal_model.dart';
import '../../repository/deal_repo.dart';
import '../../service/analytics_service.dart';
import '../../service/cart_service.dart';
import '../../util/log_service.dart';

class DealDetailsController extends GetxController {
  final DealRepo dealRepo;
  final CartService cartService;
  final AnalyticsService analytics;

  DealDetailsController({
    required this.dealRepo,
    required this.cartService,
    required this.analytics,
  });

  late DealModel deal;
  final isLoading = true.obs;

  final _quantityLeft = RxnInt();
  int? get quantityLeft => _quantityLeft.value;

  Worker? _cartItemCountWorker;

  @override
  void onInit() {
    super.onInit();
    final arguments = Get.arguments;
    if (arguments is DealModel) {
      deal = arguments;
      _quantityLeft.value = deal.quantityLeft;
      isLoading.value = false;
      analytics.logEvent('deal_details_view', {
        'deal_id': deal.id,
        'source': Get.parameters['source'] ?? 'unknown',
      });
    } else {
      _loadDealFromDeepLink();
    }
    // Whenever the cart changes, re-check this deal's remaining stock
    // so the details screen never shows stale availability.
    _cartItemCountWorker =
        ever(cartService.itemCount, (_) => _recheckAvailability());
  }

  Future<void> _loadDealFromDeepLink() async {
    try {
      final id = int.parse(Get.parameters['id']!);
      deal = await dealRepo.fetchById(id);
      _quantityLeft.value = deal.quantityLeft;
      analytics.logEvent('deal_details_view', {
        'deal_id': deal.id,
        'source': Get.parameters['source'] ?? 'unknown',
      });
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _recheckAvailability() async {
    LogService.log('re-checking availability for deal ${deal.id}');
    final fresh = await dealRepo.fetchById(deal.id);
    _quantityLeft.value = fresh.quantityLeft;
  }

  void addToCart() {
    cartService.add(deal);
    Get.snackbar(
      'Added to bag',
      '${deal.name} — pick up ${deal.pickupWindow.label}',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void onClose() {
    _cartItemCountWorker?.dispose();
    super.onClose();
  }
}

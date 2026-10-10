import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app_config.dart';
import '../../model/deal_model.dart';
import '../../service/cart_service.dart';
import '../shared_widget/flash_deals_countdown.dart';
import '../shared_widget/the_network_image.dart';
import 'deal_details_controller.dart';

class DealDetailsScreen extends GetView<DealDetailsController> {
  const DealDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }

      final deal = controller.deal;
      return Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 240,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background:
                    TheNetworkImage(url: deal.imageUrl, fit: BoxFit.cover),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(deal.name,
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold)),
                        deal.isFlashSale
                            ? FlashDealCountdown(
                                endsAt: deal.flashSaleEndsAt,
                                onExpired: () {
                                  Get.find<CartService>().expireDeal(
                                    deal.id,
                                    dealName: deal.name,
                                  );
                                },
                              )
                            : Container(),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(deal.storeName,
                        style: TextStyle(
                            fontSize: 15, color: Colors.grey.shade700)),
                    Text(deal.storeAddress,
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade500)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text('฿${deal.price.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppConfig.primaryGreen)),
                        const SizedBox(width: 8),
                        Text('฿${deal.originalPrice.toStringAsFixed(0)}',
                            style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade500,
                                decoration: TextDecoration.lineThrough)),
                        const Spacer(),
                        Obx(() => Chip(
                              avatar: const Icon(Icons.inventory_2_outlined,
                                  size: 16),
                              label: Text(
                                  '${controller.quantityLeft ?? '-'} left'),
                            )),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE0E5E2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule,
                              color: AppConfig.primaryGreen),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Pickup window',
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.grey)),
                              Text(
                                '${deal.pickupWindow.label}'
                                '${deal.pickupWindow.isToday ? ' · today' : ''}',
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const Spacer(),
                          if (deal.pickupWindow.isOpenNow)
                            const Chip(
                              label: Text('Open now'),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('What you get',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(deal.description,
                        style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: Colors.grey.shade800)),
                    if (deal.tags.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: deal.tags
                            .map((t) => Chip(
                                  label: Text(t),
                                  visualDensity: VisualDensity.compact,
                                ))
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomSheet: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          color: Colors.white,
          child: _AddToBagButton(
            deal: deal,
            onAdd: controller.addToCart,
          ),
        ),
      );
    });
  }
}

class _AddToBagButton extends StatelessWidget {
  final DealModel deal;
  final VoidCallback onAdd;

  const _AddToBagButton({
    required this.deal,
    required this.onAdd,
  });

  bool get _expired {
    final endsAt = deal.flashSaleEndsAt;
    return endsAt != null && !endsAt.isAfter(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _expired ? null : onAdd,
        icon: const Icon(Icons.add_shopping_cart),
        label: Text(_expired ? 'Expired' : 'Add to bag'),
      ),
    );
  }
}

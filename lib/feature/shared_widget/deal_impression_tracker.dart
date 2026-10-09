import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../service/analytics_service.dart';

class DealImpressionTracker extends StatefulWidget {
  const DealImpressionTracker({
    super.key,
    required this.dealId,
    required this.source,
    required this.position,
    required this.child,
  });

  final int dealId;
  final String source;
  final int position;
  final Widget child;

  @override
  State<DealImpressionTracker> createState() => _DealImpressionTrackerState();
}

class _DealImpressionTrackerState extends State<DealImpressionTracker> {
  Timer? _visibilityTimer;
  bool _isVisible = false;
  bool _reported = false;

  void _onVisibilityChanged(VisibilityInfo info) {
    final isVisible = info.visibleFraction >= 0.5;

    if (isVisible == _isVisible) return;
    _isVisible = isVisible;

    if (!isVisible) {
      _visibilityTimer?.cancel();
      _visibilityTimer = null;
      return;
    }

    if (_reported) return;

    _visibilityTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted || !_isVisible || _reported) return;

      _reported = true;

      Get.find<AnalyticsService>().trackDealImpression(
        dealId: widget.dealId,
        source: widget.source,
        position: widget.position,
      );
    });
  }

  @override
  void didUpdateWidget(covariant DealImpressionTracker oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.dealId != widget.dealId ||
        oldWidget.source != widget.source ||
        oldWidget.position != widget.position) {
      _visibilityTimer?.cancel();
      _visibilityTimer = null;
      _isVisible = false;
      _reported = false;
    }
  }

  @override
  void dispose() {
    _visibilityTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: ValueKey(
        'impression-${widget.source}-${widget.dealId}-${widget.position}',
      ),
      onVisibilityChanged: _onVisibilityChanged,
      child: widget.child,
    );
  }
}

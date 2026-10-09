import 'dart:async';
import 'package:get/get.dart';
import '../util/log_service.dart';
import './fake_api_service.dart';

class AnalyticsEvent {
  final String name;
  final Map<String, dynamic> properties;
  final DateTime at;

  AnalyticsEvent(this.name, this.properties) : at = DateTime.now();

  Map<String, dynamic> toJson() => {
        'name': name,
        'properties': properties,
        'at': at.toIso8601String(),
      };
}

class AnalyticsService extends GetxService {
  AnalyticsService({required FakeApiService api}) : _api = api;

  final FakeApiService _api;

  final events = <AnalyticsEvent>[].obs;

  // Deduplication applies across all screens for this service's app session.
  final Set<int> _impressedDealIds = <int>{};

  final List<AnalyticsEvent> _pendingBatch = <AnalyticsEvent>[];
  Timer? _batchTimer;
  bool _isFlushing = false;

  static const int _batchSize = 10;
  static const Duration _batchDelay = Duration(seconds: 15);

  void trackDealImpression({
    required int dealId,
    required String source,
    required int position,
  }) {
    if (!_impressedDealIds.add(dealId)) return;

    logEvent('deal_impression', {
      'deal_id': dealId,
      'source': source,
      'position': position,
    });
  }

  void logEvent(
    String name, [
    Map<String, dynamic> properties = const {},
  ]) {
    final event = AnalyticsEvent(name, Map<String, dynamic>.from(properties));

    // Keep this list as the source for the Analytics debug screen.
    events.add(event);
    LogService.log('analytics: $name $properties');

    _pendingBatch.add(event);

    if (_pendingBatch.length >= _batchSize) {
      unawaited(_flushBatch());
    } else {
      // Start the deadline only for the first event in an empty batch.
      _batchTimer ??= Timer(_batchDelay, () {
        unawaited(_flushBatch());
      });
    }
  }

  Future<void> _flushBatch() async {
    if (_isFlushing || _pendingBatch.isEmpty) return;

    _batchTimer?.cancel();
    _batchTimer = null;

    _isFlushing = true;

    // Snapshot and clear before awaiting, so new events can queue separately.
    final batch = List<AnalyticsEvent>.from(_pendingBatch);
    _pendingBatch.clear();

    try {
      await _api.sendAnalyticsBatch(
        batch.map((event) => event.toJson()).toList(),
      );
      LogService.log('Sent analytics batch: ${batch.length} events');
    } catch (error) {
      // Don't silently lose events if the fake API fails.
      _pendingBatch.insertAll(0, batch);
      LogService.error('Failed to send analytics batch', error);
    } finally {
      _isFlushing = false;

      if (_pendingBatch.isNotEmpty) {
        if (_pendingBatch.length >= _batchSize) {
          unawaited(_flushBatch());
        } else {
          _batchTimer ??= Timer(_batchDelay, () {
            unawaited(_flushBatch());
          });
        }
      }
    }
  }

  @override
  void onClose() {
    _batchTimer?.cancel();
    super.onClose();
  }
}

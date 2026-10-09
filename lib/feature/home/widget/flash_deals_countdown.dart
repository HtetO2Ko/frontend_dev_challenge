import 'dart:async';
import 'package:flutter/material.dart';

class FlashDealCountdown extends StatefulWidget {
  final DateTime? endsAt;

  const FlashDealCountdown({
    super.key,
    required this.endsAt,
  });

  @override
  State<FlashDealCountdown> createState() => _FlashDealCountdownState();
}

class _FlashDealCountdownState extends State<FlashDealCountdown> {
  Timer? _timer;
  late Duration _remaining;

  bool get _expired => _remaining <= Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _startTimerIfNeeded();
  }

  @override
  void didUpdateWidget(
    covariant FlashDealCountdown oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.endsAt != widget.endsAt) {
      _timer?.cancel();
      _updateRemaining();
      _startTimerIfNeeded();
    }
  }

  void _updateRemaining() {
    final endsAt = widget.endsAt;
    _remaining =
        endsAt == null ? Duration.zero : endsAt.difference(DateTime.now());
  }

  void _startTimerIfNeeded() {
    if (_expired || widget.endsAt == null) return;
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted) return;

        setState(_updateRemaining);

        if (_expired) {
          _timer?.cancel();
          _timer = null;
        }
      },
    );
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    String twoDigits(int value) => value.toString().padLeft(2, '0');

    if (hours > 0) {
      return '${twoDigits(hours)}:'
          '${twoDigits(minutes)}:'
          '${twoDigits(seconds)}';
    }

    final totalMinutes = totalSeconds ~/ 60;

    return '${twoDigits(totalMinutes)}:'
        '${twoDigits(seconds)}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.endsAt == null) {
      return const SizedBox.shrink();
    }

    final expired = _expired;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: expired ? Colors.grey.shade200 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        expired ? 'Expired' : _formatDuration(_remaining),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: expired ? Colors.grey.shade700 : Colors.red.shade700,
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// A shrinking ring around the seconds remaining on a trip offer. Ticks every
/// 100ms from [start] down to [DateTime.now], turning amber then red as time
/// runs out, and calls [onExpired] once when it hits zero.
class CountdownRing extends StatefulWidget {
  const CountdownRing({
    super.key,
    required this.start,
    required this.expiresAt,
    required this.onExpired,
    this.size = 120,
  });

  /// When the offer arrived — the full window, used as the ring's denominator.
  final DateTime start;
  final DateTime expiresAt;
  final VoidCallback onExpired;
  final double size;

  @override
  State<CountdownRing> createState() => _CountdownRingState();
}

class _CountdownRingState extends State<CountdownRing> {
  Timer? _ticker;
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() {});
      if (_remaining <= Duration.zero && !_fired) {
        _fired = true;
        widget.onExpired();
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Duration get _remaining {
    final left = widget.expiresAt.difference(DateTime.now().toUtc());
    return left.isNegative ? Duration.zero : left;
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.expiresAt.difference(widget.start).inMilliseconds;
    final remaining = _remaining.inMilliseconds;
    final fraction = total <= 0 ? 0.0 : (remaining / total).clamp(0.0, 1.0);
    final seconds = (_remaining.inMilliseconds / 1000).ceil();

    final color = fraction > 0.5
        ? AppColors.success
        : fraction > 0.25
        ? AppColors.warning
        : AppColors.danger;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: fraction,
              strokeWidth: 6,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$seconds',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              Text('sec', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

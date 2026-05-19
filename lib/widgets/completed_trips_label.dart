import 'package:flutter/material.dart';

class CompletedTripsLabel extends StatelessWidget {
  const CompletedTripsLabel({super.key, required this.count, this.compact = false});

  final int count;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = count == 1 ? '1 trip' : '$count trips';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.check_circle_outline_rounded,
          size: compact ? 14 : 15,
          color: const Color(0xFF15803D),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: compact ? cs.onSurfaceVariant : const Color(0xFF15803D),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

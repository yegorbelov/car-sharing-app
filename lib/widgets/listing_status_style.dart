import 'package:flutter/material.dart';

/// Visual style for vehicle listing status chips.
class ListingStatusStyle {
  const ListingStatusStyle({
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;

  static ListingStatusStyle forStatus(String status) {
    return switch (status) {
      'published' => const ListingStatusStyle(
        label: 'Published',
        background: Color(0xFFDCFCE7),
        foreground: Color(0xFF15803D),
        icon: Icons.check_circle_rounded,
      ),
      'pending_moderation' => const ListingStatusStyle(
        label: 'Under review',
        background: Color(0xFFFEF3C7),
        foreground: Color(0xFFB45309),
        icon: Icons.schedule_rounded,
      ),
      'unpublished' => const ListingStatusStyle(
        label: 'Unpublished',
        background: Color(0xFFF1F5F9),
        foreground: Color(0xFF64748B),
        icon: Icons.visibility_off_outlined,
      ),
      'rejected' => const ListingStatusStyle(
        label: 'Rejected',
        background: Color(0xFFFEE2E2),
        foreground: Color(0xFFB91C1C),
        icon: Icons.cancel_outlined,
      ),
      _ => ListingStatusStyle(
        label: status,
        background: const Color(0xFFF1F5F9),
        foreground: const Color(0xFF475569),
      ),
    };
  }

  /// Higher-contrast pill for photos with a dark gradient overlay.
  static ListingStatusStyle forStatusOnPhoto(String status) {
    return switch (status) {
      'published' => const ListingStatusStyle(
        label: 'Published',
        background: Color(0xF2FFFFFF),
        foreground: Color(0xFF15803D),
        icon: Icons.check_circle_rounded,
      ),
      'pending_moderation' => const ListingStatusStyle(
        label: 'Under review',
        background: Color(0xF2FFFFFF),
        foreground: Color(0xFFB45309),
        icon: Icons.schedule_rounded,
      ),
      'unpublished' => const ListingStatusStyle(
        label: 'Unpublished',
        background: Color(0xF2FFFFFF),
        foreground: Color(0xFF64748B),
        icon: Icons.visibility_off_outlined,
      ),
      'rejected' => const ListingStatusStyle(
        label: 'Rejected',
        background: Color(0xF2FFFFFF),
        foreground: Color(0xFFB91C1C),
        icon: Icons.cancel_outlined,
      ),
      _ => const ListingStatusStyle(
        label: 'Unknown',
        background: Color(0xF2FFFFFF),
        foreground: Color(0xFF475569),
      ),
    };
  }
}

class ListingStatusChip extends StatelessWidget {
  const ListingStatusChip({
    super.key,
    required this.status,
    this.onPhoto = false,
  });

  final String status;
  final bool onPhoto;

  @override
  Widget build(BuildContext context) {
    final style = onPhoto
        ? ListingStatusStyle.forStatusOnPhoto(status)
        : ListingStatusStyle.forStatus(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(20),
        border: onPhoto
            ? Border.all(color: Colors.white.withValues(alpha: 0.35))
            : null,
        boxShadow: onPhoto
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (style.icon != null) ...[
            Icon(style.icon, size: 14, color: style.foreground),
            const SizedBox(width: 4),
          ],
          Text(
            style.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: style.foreground,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.15,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Empty state with an SVG illustration from [assets/illustrations/].
class IllustratedEmptyState extends StatelessWidget {
  const IllustratedEmptyState({
    super.key,
    required this.assetPath,
    required this.title,
    this.subtitle,
    this.action,
    this.illustrationHeight = 200,
  });

  final String assetPath;
  final String title;
  final String? subtitle;
  final Widget? action;
  final double illustrationHeight;

  static const catalogEmpty = 'assets/illustrations/Electric car-amico.svg';
  static const walletEmpty = 'assets/illustrations/Plain credit card-amico.svg';
  static const orderSuccess = 'assets/illustrations/Order ahead-bro.svg';

  /// Bottom sheet shown after a rental request is created successfully.
  static Future<void> showOrderSuccess(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        final bottom = MediaQuery.paddingOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 4, 24, 16 + bottom),
          child: IllustratedEmptyState(
            assetPath: orderSuccess,
            title: 'Request sent!',
            subtitle:
                'Your security hold is in place. The owner will review your request — track it in Bookings.',
            illustrationHeight: 220,
            action: FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text('Got it'),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            assetPath,
            height: illustrationHeight,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: tt.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: 20),
            action!,
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

enum AppSnackBarKind { info, success, error }

/// Styled floating snackbar used across the app.
abstract final class AppSnackBar {
  static const _defaultDuration = Duration(milliseconds: 3500);
  static const _errorDuration = Duration(milliseconds: 4500);
  static const _fadeDuration = Duration(milliseconds: 280);

  static void show(
    BuildContext context, {
    required String message,
    AppSnackBarKind? kind,
    Duration? duration,
  }) {
    final resolved = kind ?? _inferKind(message);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final hold = duration ??
        (resolved == AppSnackBarKind.error
            ? _errorDuration
            : _defaultDuration);
    final snackDuration = Duration(
      milliseconds: _fadeDuration.inMilliseconds * 2 + hold.inMilliseconds,
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          padding: EdgeInsets.zero,
          margin: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottom),
          behavior: SnackBarBehavior.floating,
          duration: snackDuration,
          animation: const AlwaysStoppedAnimation(1),
          content: _FadingAppSnackBarBody(
            message: message,
            kind: resolved,
            fadeDuration: _fadeDuration,
            holdDuration: hold,
          ),
        ),
      );
  }

  static AppSnackBarKind _inferKind(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('failed') ||
        lower.contains('could not') ||
        lower.contains('invalid') ||
        lower.contains('error') ||
        lower.contains('cannot')) {
      return AppSnackBarKind.error;
    }
    if (lower.contains('published') ||
        lower.contains('success') ||
        lower.contains('sent!')) {
      return AppSnackBarKind.success;
    }
    return AppSnackBarKind.info;
  }
}

extension AppSnackBarContext on BuildContext {
  void showAppSnackBar(
    String message, {
    AppSnackBarKind? kind,
    Duration? duration,
  }) {
    AppSnackBar.show(
      this,
      message: message,
      kind: kind,
      duration: duration,
    );
  }
}

class _FadingAppSnackBarBody extends StatefulWidget {
  const _FadingAppSnackBarBody({
    required this.message,
    required this.kind,
    required this.fadeDuration,
    required this.holdDuration,
  });

  final String message;
  final AppSnackBarKind kind;
  final Duration fadeDuration;
  final Duration holdDuration;

  @override
  State<_FadingAppSnackBarBody> createState() => _FadingAppSnackBarBodyState();
}

class _FadingAppSnackBarBodyState extends State<_FadingAppSnackBarBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.fadeDuration,
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _runLifecycle();
  }

  Future<void> _runLifecycle() async {
    await _controller.forward();
    if (!mounted) return;
    await Future<void>.delayed(widget.holdDuration);
    if (!mounted) return;
    await _controller.reverse();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: _AppSnackBarCard(message: widget.message, kind: widget.kind),
    );
  }
}

class _AppSnackBarCard extends StatelessWidget {
  const _AppSnackBarCard({required this.message, required this.kind});

  final String message;
  final AppSnackBarKind kind;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final (icon, iconBg, iconFg) = switch (kind) {
      AppSnackBarKind.success => (
        Icons.check_circle_rounded,
        const Color(0xFFE8F5E9),
        const Color(0xFF2E7D32),
      ),
      AppSnackBarKind.error => (
        Icons.error_outline_rounded,
        const Color(0xFFFFEBEE),
        const Color(0xFFC62828),
      ),
      AppSnackBarKind.info => (
        Icons.info_outline_rounded,
        const Color(0xFFE8ECF4),
        const Color(0xFF3D4658),
      ),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E6EF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 20, color: iconFg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: tt.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  color: const Color(0xFF1A1D26),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

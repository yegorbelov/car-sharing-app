import 'package:flutter/material.dart';

/// Shared text-field styling helpers (works with [ThemeData.inputDecorationTheme]).
abstract final class AppInputs {
  static const double fieldGap = 14;
  static const double radius = 16;

  static InputDecoration decoration(
    BuildContext context, {
    required String labelText,
    String? hintText,
    IconData? icon,
    Widget? prefix,
    Widget? suffixIcon,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      alignLabelWithHint: alignLabelWithHint,
      prefixIcon: prefix ?? (icon != null ? Icon(icon, size: 22) : null),
      suffixIcon: suffixIcon,
    );
  }

  static InputDecoration search(
    BuildContext context, {
    required String hintText,
    required Widget icon,
  }) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: icon,
    );
  }

  static InputDecoration chat(BuildContext context, {String hintText = 'Message…'}) {
    return InputDecoration(
      hintText: hintText,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    );
  }
}

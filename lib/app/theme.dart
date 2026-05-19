import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  // Indigo-600: distinctive, premium, not used by typical transport apps.
  const accentBlack = Color(0xFF111111);
  const lightGrey = Color(0xFFE8E8E8);

  final scheme = ColorScheme.fromSeed(
    seedColor: accentBlack,
    brightness: Brightness.light,
    surface: const Color(0xFFF8F9FF),
    primary: accentBlack,
    onPrimary: Colors.white,
    primaryContainer: lightGrey,
    onPrimaryContainer: accentBlack,
    secondary: const Color(0xFF444444),
    onSecondary: Colors.white,
    secondaryContainer: lightGrey,
    onSecondaryContainer: accentBlack,
    tertiary: const Color(0xFF666666),
    onTertiary: Colors.white,
    tertiaryContainer: lightGrey,
    onTertiaryContainer: accentBlack,
  );

  final cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(20),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    splashFactory: InkRipple.splashFactory,

    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: scheme.onSurface,
        letterSpacing: -0.5,
      ),
    ),

    navigationBarTheme: NavigationBarThemeData(
      // M3 default with labels is tall; keep bar visually lower / slimmer.
      height: 52,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      indicatorColor: scheme.primaryContainer,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shadowColor: scheme.shadow.withValues(alpha: 0.12),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final base = TextStyle(fontSize: 9, letterSpacing: 0.1, height: 1.0);
        if (states.contains(WidgetState.selected)) {
          return base.copyWith(
            fontWeight: FontWeight.w700,
            color: scheme.primary,
          );
        }
        return base.copyWith(
          fontWeight: FontWeight.w500,
          color: scheme.onSurfaceVariant,
        );
      }),
    ),

    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: cardShape,
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hoverColor: Colors.white,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      floatingLabelStyle: WidgetStateTextStyle.resolveWith((states) {
        const base = TextStyle(fontSize: 13, letterSpacing: 0.15, height: 1.2);
        if (states.contains(WidgetState.error)) {
          return base.copyWith(color: scheme.error, fontWeight: FontWeight.w700);
        }
        if (states.contains(WidgetState.focused)) {
          return base.copyWith(color: scheme.primary, fontWeight: FontWeight.w700);
        }
        return base.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        );
      }),
      labelStyle: TextStyle(
        color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
        fontWeight: FontWeight.w500,
        fontSize: 15,
      ),
      hintStyle: TextStyle(
        color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
        fontWeight: FontWeight.w400,
        fontSize: 15,
      ),
      prefixIconColor: scheme.onSurfaceVariant.withValues(alpha: 0.75),
      suffixIconColor: scheme.onSurfaceVariant,
      prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      suffixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE4E7EF), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.error, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
    ),

    textSelectionTheme: TextSelectionThemeData(
      cursorColor: scheme.primary,
      selectionColor: scheme.primary.withValues(alpha: 0.18),
      selectionHandleColor: scheme.primary,
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          letterSpacing: 0.2,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),

    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide(color: scheme.outlineVariant),
      showCheckmark: false,
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      selectedColor: scheme.primaryContainer,
      checkmarkColor: scheme.primary,
    ),

    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 2),
    ),

    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.5),
      thickness: 1,
      space: 1,
    ),
  );
}

/// A reusable gradient decoration used as vehicle/user photo placeholder.
BoxDecoration cardGradient(ColorScheme cs) => BoxDecoration(
  gradient: LinearGradient(
    colors: [cs.primaryContainer, cs.secondaryContainer],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
);

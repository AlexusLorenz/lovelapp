import 'package:material_ui/material_ui.dart';

/// Lovel-Farbpalette.
class LovelColors {
  const LovelColors._();

  /// Graublau – Sekundärfarbe, ruhige Flächen.
  static const slate = Color(0xFF9EABBF);

  /// Creme – Karten, Text auf dunklen Flächen.
  static const cream = Color(0xFFFFFEF6);

  /// Terrakotta – Hauptfarbe, Aktionen (Like, Buttons).
  static const terracotta = Color(0xFFBB5B3E);

  /// Nebelgrau – Hintergrund.
  static const mist = Color(0xFFE0E5E7);

  /// Umbra – Akzente, Überschriften.
  static const umber = Color(0xFF803D25);

  /// Abgeleitet für gut lesbaren Fließtext (nicht Teil der Palette).
  static const ink = Color(0xFF2E211C);

  /// Abgeleitet: zarter Terrakotta-Ton für Container.
  static const blush = Color(0xFFF3DED6);
}

class AppTheme {
  const AppTheme._();

  /// Schrift für Überschriften und große Momente („MATCH!“).
  static const displayFont = 'DMSerifDisplay';

  /// Helles Theme. Ein dunkles Theme folgt später.
  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: LovelColors.terracotta,
          dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
        ).copyWith(
          primary: LovelColors.terracotta,
          onPrimary: LovelColors.cream,
          primaryContainer: LovelColors.blush,
          onPrimaryContainer: LovelColors.umber,
          secondary: LovelColors.slate,
          onSecondary: LovelColors.ink,
          secondaryContainer: LovelColors.mist,
          onSecondaryContainer: LovelColors.ink,
          tertiary: LovelColors.umber,
          onTertiary: LovelColors.cream,
          surface: LovelColors.cream,
          onSurface: LovelColors.ink,
          surfaceContainerLowest: LovelColors.cream,
          surfaceContainerLow: LovelColors.cream,
          surfaceContainer: LovelColors.cream,
          surfaceContainerHigh: LovelColors.mist,
          surfaceContainerHighest: LovelColors.mist,
          outline: LovelColors.slate,
          outlineVariant: LovelColors.mist,
        );

    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    final text = base.textTheme;
    TextStyle? display(TextStyle? s) =>
        s?.copyWith(fontFamily: displayFont, color: LovelColors.umber);

    return base.copyWith(
      scaffoldBackgroundColor: LovelColors.mist,
      textTheme: text.copyWith(
        displayLarge: display(text.displayLarge),
        displayMedium: display(text.displayMedium),
        displaySmall: display(text.displaySmall),
        headlineLarge: display(text.headlineLarge),
        headlineMedium: display(text.headlineMedium),
        headlineSmall: display(text.headlineSmall),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: LovelColors.mist,
        surfaceTintColor: Colors.transparent,
        foregroundColor: LovelColors.umber,
        titleTextStyle: const TextStyle(
          fontFamily: displayFont,
          fontSize: 28,
          color: LovelColors.umber,
        ),
      ),
      cardTheme: const CardThemeData(
        color: LovelColors.cream,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: LovelColors.cream,
        surfaceTintColor: Colors.transparent,
        indicatorColor: LovelColors.blush,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? LovelColors.terracotta
                : LovelColors.ink,
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: LovelColors.cream,
        side: const BorderSide(color: LovelColors.mist),
      ),
    );
  }
}

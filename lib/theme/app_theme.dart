// Vally Business — thème de l'application (charte graphique rose).
// Utilisation dans main.dart :
//   MaterialApp(
//     title: 'Vally Business',
//     theme: VallyTheme.light,
//     darkTheme: VallyTheme.dark,
//     themeMode: ThemeMode.system,
//     ...
//   );
// Couleurs « argent » : Theme.of(context).extension<VallyColors>()!.benefice

import 'package:material_ui/material_ui.dart';

/// Couleurs de la charte, en clair et en sombre.
class VallyPalette {
  // Clair
  static const rose = Color(0xFFC2255C);
  static const roseDeep = Color(0xFF8F1D45);
  static const roseSoft = Color(0xFFFCE4EC);
  static const rosePop = Color(0xFFF783AC); // décoratif uniquement, jamais pour du texte
  static const surface = Color(0xFFFFF7FA);
  static const surfaceRaised = Color(0xFFFFFFFF);
  static const ink = Color(0xFF2A1520);
  static const inkMuted = Color(0xFF6E5562);
  static const line = Color(0xFFF0D5DF);
  static const benefice = Color(0xFF1F7A55);
  static const attention = Color(0xFFA84B0C);

  // Sombre
  static const roseDark = Color(0xFFF06595);
  static const roseDeepDark = Color(0xFFFFB3CC);
  static const roseSoftDark = Color(0xFF4A2233);
  static const surfaceDark = Color(0xFF1E1218);
  static const surfaceRaisedDark = Color(0xFF2A1A22);
  static const inkDark = Color(0xFFFBEFF4);
  static const inkMutedDark = Color(0xFFC9AEBB);
  static const lineDark = Color(0xFF3E2731);
  static const beneficeDark = Color(0xFF5BC39A);
  static const attentionDark = Color(0xFFF2A541);
}

/// Couleurs propres à l'appli : bénéfice (vert) et attention (ambre).
/// Toujours accompagnées d'un signe + / − ou d'une icône.
@immutable
class VallyColors extends ThemeExtension<VallyColors> {
  const VallyColors({
    required this.benefice,
    required this.attention,
    required this.rosePop,
  });

  final Color benefice;  // bénéfice, entrée d'argent, commande soldée
  final Color attention; // sortie d'argent, reste à payer, stock faible, remise
  final Color rosePop;   // graphiques et décorations

  static const light = VallyColors(
    benefice: VallyPalette.benefice,
    attention: VallyPalette.attention,
    rosePop: VallyPalette.rosePop,
  );
  static const dark = VallyColors(
    benefice: VallyPalette.beneficeDark,
    attention: VallyPalette.attentionDark,
    rosePop: VallyPalette.rosePop,
  );

  @override
  VallyColors copyWith({Color? benefice, Color? attention, Color? rosePop}) =>
      VallyColors(
        benefice: benefice ?? this.benefice,
        attention: attention ?? this.attention,
        rosePop: rosePop ?? this.rosePop,
      );

  @override
  VallyColors lerp(ThemeExtension<VallyColors>? other, double t) {
    if (other is! VallyColors) return this;
    return VallyColors(
      benefice: Color.lerp(benefice, other.benefice, t)!,
      attention: Color.lerp(attention, other.attention, t)!,
      rosePop: Color.lerp(rosePop, other.rosePop, t)!,
    );
  }
}

/// Espacements (grille de 4) et rayons.
class VallySpace {
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s4 = 16.0; // marge des écrans, padding des cartes
  static const s6 = 24.0; // entre sections
}

class VallyRadius {
  static const sm = 8.0;  // champs, badges
  static const md = 16.0; // cartes, boutons
  static const pill = 999.0;
}

class VallyTheme {
  static const _display = 'DMSerifDisplay';
  static const _sans = 'Inter';
  static const _tabular = [FontFeature.tabularFigures()];

  static ThemeData get light => _build(
        brightness: Brightness.light,
        rose: VallyPalette.rose,
        onRose: Colors.white,
        roseDeep: VallyPalette.roseDeep,
        roseSoft: VallyPalette.roseSoft,
        surface: VallyPalette.surface,
        surfaceRaised: VallyPalette.surfaceRaised,
        ink: VallyPalette.ink,
        inkMuted: VallyPalette.inkMuted,
        line: VallyPalette.line,
        error: VallyPalette.attention,
        extra: VallyColors.light,
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        rose: VallyPalette.roseDark,
        onRose: VallyPalette.surfaceDark,
        roseDeep: VallyPalette.roseDeepDark,
        roseSoft: VallyPalette.roseSoftDark,
        surface: VallyPalette.surfaceDark,
        surfaceRaised: VallyPalette.surfaceRaisedDark,
        ink: VallyPalette.inkDark,
        inkMuted: VallyPalette.inkMutedDark,
        line: VallyPalette.lineDark,
        error: VallyPalette.attentionDark,
        extra: VallyColors.dark,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color rose,
    required Color onRose,
    required Color roseDeep,
    required Color roseSoft,
    required Color surface,
    required Color surfaceRaised,
    required Color ink,
    required Color inkMuted,
    required Color line,
    required Color error,
    required VallyColors extra,
  }) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: rose,
      onPrimary: onRose,
      primaryContainer: roseSoft,
      onPrimaryContainer: roseDeep,
      secondary: roseDeep,
      onSecondary: onRose,
      secondaryContainer: roseSoft,
      onSecondaryContainer: roseDeep,
      error: error,
      onError: brightness == Brightness.light ? Colors.white : surface,
      surface: surface,
      onSurface: ink,
      onSurfaceVariant: inkMuted,
      surfaceContainerLowest: surfaceRaised,
      surfaceContainerLow: surfaceRaised,
      surfaceContainer: surfaceRaised,
      surfaceContainerHigh: surfaceRaised,
      outline: inkMuted,
      outlineVariant: line,
    );

    final text = TextTheme(
      // Grands montants du tableau de bord
      displaySmall: TextStyle(fontFamily: _display, fontSize: 40, height: 44 / 40, color: ink, fontFeatures: _tabular),
      // Titres d'écran
      headlineSmall: TextStyle(fontFamily: _display, fontSize: 28, height: 34 / 28, color: ink),
      // Titres de section
      titleMedium: TextStyle(fontFamily: _sans, fontSize: 18, height: 24 / 18, fontWeight: FontWeight.w600, color: ink),
      // Montants dans les listes
      titleSmall: TextStyle(fontFamily: _sans, fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w600, color: ink, fontFeatures: _tabular),
      // Corps
      bodyLarge: TextStyle(fontFamily: _sans, fontSize: 16, height: 24 / 16, color: ink),
      bodyMedium: TextStyle(fontFamily: _sans, fontSize: 14, height: 20 / 14, color: ink),
      // Libellés
      labelLarge: TextStyle(fontFamily: _sans, fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w500, color: ink),
      bodySmall: TextStyle(fontFamily: _sans, fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w500, color: inkMuted),
      labelSmall: TextStyle(fontFamily: _sans, fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w500, color: inkMuted),
    );

    final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(VallyRadius.md));

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: _sans,
      textTheme: text,
      scaffoldBackgroundColor: surface,
      extensions: [extra],
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: text.headlineSmall,
      ),
      cardTheme: CardThemeData(
        color: surfaceRaised,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VallyRadius.md),
          side: BorderSide(color: line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: rose,
          foregroundColor: onRose,
          minimumSize: const Size.fromHeight(52),
          shape: rounded,
          textStyle: const TextStyle(fontFamily: _sans, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: rose,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: line),
          shape: rounded,
          textStyle: const TextStyle(fontFamily: _sans, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: rose,
        foregroundColor: onRose,
        elevation: 2,
        shape: const StadiumBorder(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceRaised,
        contentPadding: const EdgeInsets.symmetric(horizontal: VallySpace.s4, vertical: 14),
        labelStyle: TextStyle(color: inkMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VallyRadius.sm),
          borderSide: BorderSide(color: inkMuted),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VallyRadius.sm),
          borderSide: BorderSide(color: inkMuted),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VallyRadius.sm),
          borderSide: BorderSide(color: rose, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceRaised,
        selectedColor: roseSoft,
        labelStyle: TextStyle(fontFamily: _sans, color: ink, fontWeight: FontWeight.w500),
        side: BorderSide(color: line),
        shape: const StadiumBorder(),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceRaised,
        indicatorColor: roseSoft,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? roseDeep : inkMuted),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontFamily: _sans,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: s.contains(WidgetState.selected) ? roseDeep : inkMuted,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
    );
  }
}

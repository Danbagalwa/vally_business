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
  // Barres des graphiques (validé : bande de luminosité + contraste sur les cartes).
  static const graphique = Color(0xFFC2255C);
  static const graphiqueDark = Color(0xFFE64A85);
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

/// Couleurs propres à l'appli : bénéfice (vert) et attention (ambre),
/// toujours accompagnées d'un signe + / − ou d'une icône ; graphique ;
/// carte héro (dégradé de marque) et sa tuile « action ».
@immutable
class VallyColors extends ThemeExtension<VallyColors> {
  const VallyColors({
    required this.benefice,
    required this.attention,
    required this.rosePop,
    required this.graphique,
    required this.heroDebut,
    required this.heroFin,
    required this.heroAction,
    required this.heroSurAction,
  });

  final Color benefice;  // bénéfice, entrée d'argent, commande soldée
  final Color attention; // sortie d'argent, reste à payer, stock faible, remise
  final Color rosePop;   // décorations
  final Color graphique; // marques des graphiques (barres)
  final Color heroDebut; // carte héro : dégradé (texte blanc dessus)
  final Color heroFin;
  final Color heroAction;    // tuile qui demande une action, sur la carte héro
  final Color heroSurAction; // texte de cette tuile

  static const light = VallyColors(
    benefice: VallyPalette.benefice,
    attention: VallyPalette.attention,
    rosePop: VallyPalette.rosePop,
    graphique: VallyPalette.graphique,
    heroDebut: VallyPalette.rose,
    heroFin: VallyPalette.roseDeep,
    heroAction: VallyPalette.surfaceRaised,
    heroSurAction: VallyPalette.roseDeep,
  );
  static const dark = VallyColors(
    benefice: VallyPalette.beneficeDark,
    attention: VallyPalette.attentionDark,
    rosePop: VallyPalette.rosePop,
    graphique: VallyPalette.graphiqueDark,
    heroDebut: VallyPalette.roseDeep,
    heroFin: VallyPalette.roseSoftDark,
    heroAction: VallyPalette.roseDeepDark,
    heroSurAction: VallyPalette.ink,
  );

  @override
  VallyColors copyWith({
    Color? benefice,
    Color? attention,
    Color? rosePop,
    Color? graphique,
    Color? heroDebut,
    Color? heroFin,
    Color? heroAction,
    Color? heroSurAction,
  }) =>
      VallyColors(
        benefice: benefice ?? this.benefice,
        attention: attention ?? this.attention,
        rosePop: rosePop ?? this.rosePop,
        graphique: graphique ?? this.graphique,
        heroDebut: heroDebut ?? this.heroDebut,
        heroFin: heroFin ?? this.heroFin,
        heroAction: heroAction ?? this.heroAction,
        heroSurAction: heroSurAction ?? this.heroSurAction,
      );

  @override
  VallyColors lerp(ThemeExtension<VallyColors>? other, double t) {
    if (other is! VallyColors) return this;
    return VallyColors(
      benefice: Color.lerp(benefice, other.benefice, t)!,
      attention: Color.lerp(attention, other.attention, t)!,
      rosePop: Color.lerp(rosePop, other.rosePop, t)!,
      graphique: Color.lerp(graphique, other.graphique, t)!,
      heroDebut: Color.lerp(heroDebut, other.heroDebut, t)!,
      heroFin: Color.lerp(heroFin, other.heroFin, t)!,
      heroAction: Color.lerp(heroAction, other.heroAction, t)!,
      heroSurAction: Color.lerp(heroSurAction, other.heroSurAction, t)!,
    );
  }
}

/// Espacements : grille de 2 (valeurs les plus utilisées).
class VallySpace {
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0; // marge des écrans
  static const s5 = 20.0;
  static const s6 = 24.0; // entre sections
  static const entreCartes = 10.0;
  static const paddingCarte = 14.0;
  static const section = 28.0;
}

/// Rayons : 10 · 12 · 14 · 16 · 20.
class VallyRadius {
  static const xs = 10.0;  // boutons compacts, miniatures
  static const sm = 12.0;  // boutons, champs, bandeaux, notes
  static const r14 = 14.0; // sous-blocs, tuiles 48 px
  static const md = 16.0;  // cartes
  static const lg = 20.0;  // carte héro, pilules
  static const pill = 999.0;
}

class VallyTheme {
  // Titres : Space Grotesk Bold. Reste : police du système (Roboto sur
  // Android, San Francisco sur iPhone) — null = police par défaut.
  static const _display = 'SpaceGrotesk';
  static const String? _sans = null;
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

    // Échelle de texte compacte, adaptée au téléphone.
    final text = TextTheme(
      // Échelle réduite (2026-11-19) : environ 1 à 2 points de moins,
      // plancher à 10,5 px pour rester lisible.
      // Grand montant (chiffre principal d'un écran)
      displaySmall: TextStyle(fontFamily: _display, fontWeight: FontWeight.w700, letterSpacing: -0.5, fontSize: 28, height: 34 / 28, color: ink, fontFeatures: _tabular),
      // Titre d'écran mis en avant
      headlineSmall: TextStyle(fontFamily: _display, fontWeight: FontWeight.w700, letterSpacing: -0.3, fontSize: 21, height: 27 / 21, color: ink),
      // Titre de barre d'application
      titleLarge: TextStyle(fontFamily: _display, fontWeight: FontWeight.w700, letterSpacing: -0.3, fontSize: 19, height: 24 / 19, color: ink),
      // Titres de section
      titleMedium: TextStyle(fontFamily: _sans, fontSize: 15, height: 20 / 15, fontWeight: FontWeight.w600, color: ink),
      // Montants dans les listes
      titleSmall: TextStyle(fontFamily: _sans, fontSize: 14, height: 19 / 14, fontWeight: FontWeight.w600, color: ink, fontFeatures: _tabular),
      // Corps
      bodyLarge: TextStyle(fontFamily: _sans, fontSize: 14, height: 20 / 14, color: ink),
      bodyMedium: TextStyle(fontFamily: _sans, fontSize: 13, height: 18 / 13, color: ink),
      bodySmall: TextStyle(fontFamily: _sans, fontSize: 11.5, height: 15 / 11.5, color: inkMuted),
      // Libellés (boutons, pastilles)
      labelLarge: TextStyle(fontFamily: _sans, fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w600, color: ink),
      labelMedium: TextStyle(fontFamily: _sans, fontSize: 11.5, height: 15 / 11.5, fontWeight: FontWeight.w500, color: ink),
      labelSmall: TextStyle(fontFamily: _sans, fontSize: 10.5, height: 14 / 10.5, fontWeight: FontWeight.w500, color: inkMuted),
    );

    // Méthode de design : boutons 46 px rayon 12, champs remplis sans
    // bordure au repos (liseré rose 1,6 px au focus), AppBar fondue.
    final arrondi = RoundedRectangleBorder(borderRadius: BorderRadius.circular(VallyRadius.sm));
    const texteBouton = TextStyle(fontFamily: _sans, fontSize: 13, fontWeight: FontWeight.w700);
    const tailleBouton = Size(64, 46);
    const paddingBouton = EdgeInsets.symmetric(horizontal: 20);
    final clair = brightness == Brightness.light;
    final fondChamp = ink.withValues(alpha: clair ? 0.05 : 0.06);
    final bordChamp = OutlineInputBorder(
      borderRadius: BorderRadius.circular(VallyRadius.sm),
      borderSide: BorderSide.none,
    );
    Color selonFocus(Set<WidgetState> s) =>
        s.contains(WidgetState.error) ? error : (s.contains(WidgetState.focused) ? rose : inkMuted);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: _sans,
      textTheme: text,
      scaffoldBackgroundColor: surface,
      extensions: [extra],
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: line,
        centerTitle: false,
        toolbarHeight: 56,
        titleTextStyle: text.titleLarge,
        actionsIconTheme: IconThemeData(color: ink, size: 21),
      ),
      cardTheme: CardThemeData(
        // Cartes en blanc pur (sombre : carte de la charte), sans teinte Material 3.
        color: surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VallyRadius.md),
          side: BorderSide(color: line.withValues(alpha: clair ? 1 : 0.8)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: rose,
          foregroundColor: onRose,
          minimumSize: tailleBouton,
          padding: paddingBouton,
          shape: arrondi,
          textStyle: texteBouton,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: rose,
          minimumSize: tailleBouton,
          padding: paddingBouton,
          side: BorderSide(color: line),
          shape: arrondi,
          textStyle: texteBouton,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: rose,
          minimumSize: const Size(48, 40),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VallyRadius.xs)),
          textStyle: texteBouton.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: rose,
        foregroundColor: onRose,
        elevation: 2,
        highlightElevation: 4,
        shape: const StadiumBorder(),
        extendedPadding: const EdgeInsets.symmetric(horizontal: 18),
        extendedTextStyle: texteBouton,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fondChamp,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        labelStyle: TextStyle(color: inkMuted, fontSize: 13),
        floatingLabelStyle: TextStyle(color: roseDeep, fontSize: 13, fontWeight: FontWeight.w600),
        hintStyle: TextStyle(color: inkMuted, fontSize: 13),
        helperStyle: TextStyle(color: inkMuted, fontSize: 11.5),
        border: bordChamp,
        enabledBorder: bordChamp,
        disabledBorder: bordChamp,
        focusedBorder: bordChamp.copyWith(borderSide: BorderSide(color: rose, width: 1.6)),
        errorBorder: bordChamp.copyWith(borderSide: BorderSide(color: error, width: 1.2)),
        focusedErrorBorder: bordChamp.copyWith(borderSide: BorderSide(color: error, width: 1.6)),
        prefixIconColor: WidgetStateColor.resolveWith(selonFocus),
        suffixIconColor: WidgetStateColor.resolveWith(selonFocus),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceRaised,
        selectedColor: roseSoft,
        labelStyle: TextStyle(fontFamily: _sans, fontSize: 12, color: ink, fontWeight: FontWeight.w500),
        secondaryLabelStyle: TextStyle(fontFamily: _sans, fontSize: 12, color: roseDeep, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        side: BorderSide(color: line),
        shape: const StadiumBorder(),
        showCheckmark: false,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          textStyle: const TextStyle(fontFamily: _sans, fontSize: 12, fontWeight: FontWeight.w500),
          selectedBackgroundColor: roseSoft,
          selectedForegroundColor: roseDeep,
          side: BorderSide(color: line),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minVerticalPadding: 8,
        iconColor: inkMuted,
        titleTextStyle: text.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
        subtitleTextStyle: text.bodySmall,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        backgroundColor: surfaceRaised,
        indicatorColor: roseSoft,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(size: 22, color: s.contains(WidgetState.selected) ? roseDeep : inkMuted),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontFamily: _sans,
            fontSize: 10.5,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? roseDeep : inkMuted,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VallyRadius.sm)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceRaised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VallyRadius.md)),
        titleTextStyle: text.titleMedium?.copyWith(fontSize: 17),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? onRose : inkMuted),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? rose : line),
      ),
      dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
    );
  }
}

import 'package:material_ui/material_ui.dart';

import '../../theme/app_theme.dart';

/// Variation en % : « +12 % » (vert bénéfice), « −8 % » (ambre attention),
/// neutre sous 0,5 %. [bonQuandHausse] à faux pour ce qui doit baisser
/// (remises, reste dû). Signe « − » typographique, virgule décimale.
class DeltaTexte extends StatelessWidget {
  const DeltaTexte(this.pourcent, {super.key, this.bonQuandHausse = true, this.style, this.surFonce = false});

  final double? pourcent;
  final bool bonQuandHausse;
  final TextStyle? style;

  /// Sur la carte héro : texte blanc, sans couleur de statut.
  final bool surFonce;

  static String formater(double p) {
    final abs = p.abs();
    final texte = abs < 10 ? abs.toStringAsFixed(1).replaceAll('.', ',') : abs.round().toString();
    final signe = p > 0 ? '+' : '−';
    return '$signe$texte %';
  }

  @override
  Widget build(BuildContext context) {
    final p = pourcent;
    if (p == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final vally = theme.extension<VallyColors>()!;
    final neutre = p.abs() < 0.5;
    final bon = (p > 0) == bonQuandHausse;
    final couleur = surFonce
        ? Colors.white
        : neutre
            ? theme.colorScheme.onSurfaceVariant
            : (bon ? vally.benefice : vally.attention);
    return Semantics(
      label: neutre ? 'Stable' : '${p > 0 ? 'En hausse' : 'En baisse'} de ${formater(p).substring(1)}',
      excludeSemantics: true,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          neutre ? Icons.trending_flat : (p > 0 ? Icons.trending_up : Icons.trending_down),
          size: 15,
          color: couleur,
        ),
        const SizedBox(width: 3),
        Text(neutre ? '=' : formater(p),
            style: (style ?? theme.textTheme.labelMedium)?.copyWith(
                color: couleur,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()])),
      ]),
    );
  }
}

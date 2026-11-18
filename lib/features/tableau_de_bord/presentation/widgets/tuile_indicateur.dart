import 'package:material_ui/material_ui.dart';

import '../../../../core/format/montant.dart';
import '../../../../core/widgets/delta_texte.dart';
import '../../../../core/widgets/montant_texte.dart';
import '../../../../theme/app_theme.dart';

/// Tuile KPI : icône + variation en haut, valeur en grand, libellé dessous.
class TuileIndicateur extends StatelessWidget {
  const TuileIndicateur({
    super.key,
    required this.libelle,
    required this.devise,
    this.montant,
    this.valeurTexte,
    this.sens = SensMontant.neutre,
    this.icone,
    this.precision,
    this.variation,
    this.bonQuandHausse = true,
  });

  final String libelle;
  final Devise devise;

  /// Montant affiché (ou [valeurTexte] pour un nombre simple : « 12 »).
  final double? montant;
  final String? valeurTexte;
  final SensMontant sens;
  final IconData? icone;
  final String? precision;

  /// Variation en % par rapport à la période précédente.
  final double? variation;
  final bool bonQuandHausse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vally = theme.extension<VallyColors>()!;
    final couleurIcone = switch (sens) {
      SensMontant.positif => vally.benefice,
      SensMontant.negatif => vally.attention,
      SensMontant.neutre => theme.colorScheme.primary,
    };
    final valeurStyle = theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w800, fontSize: 17, fontFeatures: const [FontFeature.tabularFigures()]);
    final m = montant;
    // Un montant nul ne porte pas de signe.
    final sensAffiche = m == null || m.abs() < 0.005 ? SensMontant.neutre : sens;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              if (icone != null) Icon(icone, size: 18, color: couleurIcone),
              const Spacer(),
              DeltaTexte(variation, bonQuandHausse: bonQuandHausse),
            ]),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: m != null
                  ? MontantTexte(m.abs(), devise: devise, sens: sensAffiche, style: valeurStyle)
                  : Text(valeurTexte ?? '—', style: valeurStyle),
            ),
            const SizedBox(height: 2),
            Text(libelle, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (precision != null)
              Text(precision!, style: theme.textTheme.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

/// Deux tuiles côte à côte, de même hauteur.
class RangeeTuiles extends StatelessWidget {
  const RangeeTuiles({super.key, required this.gauche, required this.droite});

  final Widget gauche;
  final Widget droite;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: gauche),
            const SizedBox(width: 10),
            Expanded(child: droite),
          ],
        ),
      ),
    );
  }
}

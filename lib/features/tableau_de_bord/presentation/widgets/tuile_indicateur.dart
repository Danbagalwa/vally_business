import 'package:material_ui/material_ui.dart';

import '../../../../core/format/montant.dart';
import '../../../../core/widgets/montant_texte.dart';
import '../../../../theme/app_theme.dart';

/// Tuile chiffrée : libellé, montant, précision facultative.
class TuileIndicateur extends StatelessWidget {
  const TuileIndicateur({
    super.key,
    required this.libelle,
    required this.montant,
    required this.devise,
    this.sens = SensMontant.neutre,
    this.icone,
    this.precision,
  });

  final String libelle;
  final double montant;
  final Devise devise;
  final SensMontant sens;
  final IconData? icone;
  final String? precision;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vally = theme.extension<VallyColors>()!;
    final couleurIcone = switch (sens) {
      SensMontant.positif => vally.benefice,
      SensMontant.negatif => vally.attention,
      SensMontant.neutre => theme.colorScheme.onSurfaceVariant,
    };
    // Un montant nul ne porte pas de signe.
    final sensAffiche = montant.abs() < 0.005 ? SensMontant.neutre : sens;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(VallySpace.s4 - VallySpace.s1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              if (icone != null) ...[
                Icon(icone, size: 16, color: couleurIcone),
                const SizedBox(width: VallySpace.s1),
              ],
              Expanded(
                child: Text(libelle,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
            const SizedBox(height: VallySpace.s1),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: MontantTexte(montant.abs(),
                  devise: devise,
                  sens: sensAffiche,
                  style: theme.textTheme.titleMedium),
            ),
            if (precision != null)
              Text(precision!,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

/// Deux tuiles côte à côte.
class RangeeTuiles extends StatelessWidget {
  const RangeeTuiles({super.key, required this.gauche, required this.droite});

  final Widget gauche;
  final Widget droite;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: gauche),
          const SizedBox(width: VallySpace.s2),
          Expanded(child: droite),
        ],
      ),
    );
  }
}

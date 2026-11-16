import 'package:material_ui/material_ui.dart';

import '../../theme/app_theme.dart';
import '../format/montant.dart';

/// Affiche un montant selon la charte : chiffres tabulaires, bénéfice en vert
/// avec « + », sorties et reste à payer en ambre avec « − ».
class MontantTexte extends StatelessWidget {
  const MontantTexte(
    this.montant, {
    super.key,
    required this.devise,
    this.sens = SensMontant.neutre,
    this.style,
  });

  final num montant;
  final Devise devise;
  final SensMontant sens;

  /// Style de base (par défaut : `titleSmall`, déjà en chiffres tabulaires).
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vally = theme.extension<VallyColors>()!;
    final couleur = switch (sens) {
      SensMontant.positif => vally.benefice,
      SensMontant.negatif => vally.attention,
      SensMontant.neutre => null,
    };
    final base = style ?? theme.textTheme.titleSmall;
    return Text(
      FormatMontant.formater(montant, devise, sens: sens),
      style: base?.copyWith(
        color: couleur,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

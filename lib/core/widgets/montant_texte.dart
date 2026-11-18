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

/// Morceau de texte « montant » à glisser dans un [TexteAvecMontants]
/// (même règles de couleur et de signe que [MontantTexte]).
TextSpan spanMontant(
  BuildContext context,
  num montant,
  Devise devise, {
  SensMontant sens = SensMontant.neutre,
  bool gras = false,
}) {
  final vally = Theme.of(context).extension<VallyColors>()!;
  return TextSpan(
    text: FormatMontant.formater(montant, devise, sens: sens),
    style: TextStyle(
      color: switch (sens) {
        SensMontant.positif => vally.benefice,
        SensMontant.negatif => vally.attention,
        SensMontant.neutre => null,
      },
      fontWeight: gras ? FontWeight.w600 : null,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );
}

/// Texte mêlant libellés et montants, qui passe à la ligne ou se coupe
/// proprement au lieu de déborder (« Reste − 8 000 CDF », « + 2 000 CDF de remise »).
class TexteAvecMontants extends StatelessWidget {
  const TexteAvecMontants(this.morceaux, {super.key, this.style, this.maxLines = 2});

  /// Chaînes (texte simple) ou [TextSpan] (montants, via [spanMontant]).
  final List<Object> morceaux;
  final TextStyle? style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: [
        for (final m in morceaux) m is InlineSpan ? m : TextSpan(text: '$m'),
      ]),
      style: style ?? Theme.of(context).textTheme.bodySmall,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}

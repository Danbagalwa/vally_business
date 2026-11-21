// Éléments du « carnet de la boutique » : le style commun à l'accueil et aux
// onglets. Des titres écrits comme des phrases, des cartes-registres (une
// ligne par client, par vente, par article) fermées par un total, et une
// phrase de résumé où seuls les chiffres ressortent.
import 'package:material_ui/material_ui.dart';

import '../../theme/app_theme.dart';
import '../format/montant.dart';
import 'montant_texte.dart';

/// Titre de section écrit comme une phrase (jamais en majuscules), dans la
/// police des titres. À droite : un lien (« Tout voir ») ou un détail discret.
class TitreSection extends StatelessWidget {
  const TitreSection(
    this.titre, {
    super.key,
    this.lien,
    this.onLien,
    this.detail,
    this.alerte = false,
    this.taille = 18,
    this.marge = const EdgeInsets.only(top: VallySpace.section, bottom: 10),
  });

  final String titre;
  final String? lien;
  final VoidCallback? onLien;

  /// Texte discret à droite (« 2 commandes »), affiché s'il n'y a pas de lien.
  final Widget? detail;

  /// Titre en ambre précédé d'une icône (ex. : commandes en retard).
  final bool alerte;

  /// 18 pour une section, 16 pour un groupe dans une liste (un jour…).
  final double taille;
  final EdgeInsetsGeometry marge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final vally = theme.extension<VallyColors>()!;
    return Padding(
      padding: marge,
      child: Row(children: [
        if (alerte) ...[
          Icon(Icons.warning_amber_rounded, size: taille, color: vally.attention),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              titre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: taille,
                color: alerte ? vally.attention : scheme.onSurface,
              ),
            ),
          ),
        ),
        if (lien != null)
          Semantics(
            button: true,
            excludeSemantics: true,
            label: lien,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onLien,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                child: Text(lien!,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w600)),
              ),
            ),
          )
        else if (detail != null) ...[
          const SizedBox(width: 12),
          DefaultTextStyle.merge(
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            child: detail!,
          ),
        ],
      ]),
    );
  }
}

/// Phrase de résumé (« Tu as déjà fait 3 ventes… ») : les nombres et les
/// montants ressortent en gras, le reste de la phrase reste discret.
class PhraseAvecChiffres extends StatelessWidget {
  const PhraseAvecChiffres(this.phrase, {super.key});

  final String phrase;

  /// Un nombre, ses milliers (« 80 000 »), ses décimales et sa devise.
  static final _nombre =
      RegExp(r'\d+(?:[   ]\d{3})*(?:,\d+)?(?:[   ](?:CDF|USD))?');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final base = theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant, height: 1.4);
    final fort = TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w700);
    final morceaux = <InlineSpan>[];
    phrase.splitMapJoin(
      _nombre,
      onMatch: (m) {
        morceaux.add(TextSpan(text: m[0], style: fort));
        return '';
      },
      onNonMatch: (t) {
        morceaux.add(TextSpan(text: t));
        return '';
      },
    );
    return Text.rich(TextSpan(children: morceaux), style: base);
  }
}

/// Bas d'une carte-registre, comme le total en bas d'une page de cahier :
/// libellé à gauche, montant à droite, sur un fond à peine teinté.
class PiedDeCarte extends StatelessWidget {
  const PiedDeCarte({
    super.key,
    required this.libelle,
    required this.montant,
    required this.devise,
    this.sens = SensMontant.neutre,
  });

  final String libelle;
  final double montant;
  final Devise devise;

  /// Reste à encaisser, dettes : ambre avec « − » (charte).
  final SensMontant sens;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      color: scheme.onSurface.withValues(alpha: 0.03),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(children: [
        Expanded(
          child: Text(libelle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
        ),
        const SizedBox(width: 12),
        MontantTexte(montant,
            devise: devise,
            sens: sens,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// Séparateur entre deux lignes d'une carte-registre (marges de 16 px).
class TraitRegistre extends StatelessWidget {
  const TraitRegistre({super.key, this.retrait = 16});

  /// Retrait à gauche (pour s'aligner sur le texte quand la ligne a une icône).
  final double retrait;

  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, indent: retrait, endIndent: 16);
}

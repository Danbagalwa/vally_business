import 'package:material_ui/material_ui.dart';

import '../../../../core/format/montant.dart';
import '../../../../core/widgets/elements.dart';
import '../../../../core/widgets/montant_texte.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/article.dart';
import 'photo_article.dart';

/// Ligne compacte de la liste du stock.
class ArticleTuile extends StatelessWidget {
  const ArticleTuile({
    super.key,
    required this.article,
    required this.devise,
    this.onTap,
  });

  final Article article;
  final Devise devise;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
        child: Row(children: [
          PhotoArticle(chemin: article.photoChemin, taille: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(article.nom,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text(article.description,
                  style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [
                if (article.pourEnfant) ...[
                  const Pastille(texte: 'Enfant', icone: Icons.child_care),
                  const SizedBox(width: 6),
                ],
                Flexible(child: BadgeStock(article: article)),
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          MontantTexte(article.prixVenteHabituel, devise: devise, style: theme.textTheme.titleSmall),
        ]),
      ),
    );
  }
}

/// « 3 / 5 en stock », « Plus que 2 », « Épuisé ».
/// Stock faible et épuisé : couleur attention + icône (charte).
class BadgeStock extends StatelessWidget {
  const BadgeStock({super.key, required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vally = theme.extension<VallyColors>()!;
    if (article.epuise) {
      return Pastille(texte: 'Épuisé', icone: Icons.remove_shopping_cart_outlined, couleur: vally.attention);
    }
    if (article.stockFaible) {
      return Pastille(
          texte: 'Plus que ${article.quantiteRestante} en stock',
          icone: Icons.warning_amber_rounded,
          couleur: vally.attention);
    }
    return Text('${article.quantiteRestante} / ${article.quantiteAchetee} en stock',
        style: theme.textTheme.bodySmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]));
  }
}

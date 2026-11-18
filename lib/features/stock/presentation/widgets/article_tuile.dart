import 'package:material_ui/material_ui.dart';

import '../../../../core/format/montant.dart';
import '../../../../core/widgets/montant_texte.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/article.dart';
import 'photo_article.dart';

/// Ligne de la liste du stock.
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
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(VallySpace.s2 + VallySpace.s1),
          child: Row(
            children: [
              PhotoArticle(chemin: article.photoChemin),
              const SizedBox(width: VallySpace.s4 - VallySpace.s1),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(article.nom,
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(article.description,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: VallySpace.s1),
                    BadgeStock(article: article),
                  ],
                ),
              ),
              const SizedBox(width: VallySpace.s2),
              MontantTexte(article.prixVenteHabituel, devise: devise),
            ],
          ),
        ),
      ),
    );
  }
}

/// « 3 / 5 en stock », « Plus que 1 », « Épuisé ».
/// Stock faible et épuisé : couleur attention + icône (charte).
class BadgeStock extends StatelessWidget {
  const BadgeStock({super.key, required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vally = theme.extension<VallyColors>()!;
    final style = theme.textTheme.bodySmall
        ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

    if (article.epuise || article.stockFaible) {
      final texte = article.epuise
          ? 'Épuisé'
          : 'Plus que ${article.quantiteRestante} en stock';
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
              article.epuise
                  ? Icons.remove_shopping_cart_outlined
                  : Icons.warning_amber_rounded,
              size: 16,
              color: vally.attention),
          const SizedBox(width: VallySpace.s1),
          Text(texte, style: style?.copyWith(color: vally.attention)),
        ],
      );
    }
    return Text(
        '${article.quantiteRestante} / ${article.quantiteAchetee} en stock',
        style: style);
  }
}

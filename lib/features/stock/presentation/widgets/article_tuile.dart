import 'package:material_ui/material_ui.dart';

import '../../../../core/format/montant.dart';
import '../../../../core/widgets/montant_texte.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/article.dart';
import 'photo_article.dart';

/// Une ligne de l'inventaire : photo, nom et prix, description, puis ce
/// qu'il en reste.
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
    final a = article;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          PhotoArticle(chemin: a.photoChemin, taille: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Text(a.nom,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 10),
                MontantTexte(a.prixVenteHabituel,
                    devise: devise,
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 2),
              Text(
                [a.description, if (a.pourEnfant) 'Enfant'].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12.5),
              ),
              const SizedBox(height: 4),
              BadgeStock(article: a),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Ce qu'il reste, en quelques mots : « Il en reste 7 sur 10 » ; en ambre
/// avec une icône (charte) : « Plus qu'une pièce », « Épuisé ».
class BadgeStock extends StatelessWidget {
  const BadgeStock({super.key, required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vally = theme.extension<VallyColors>()!;
    final petit = theme.textTheme.bodySmall?.copyWith(fontSize: 12.5);
    final a = article;
    if (a.epuise || a.stockFaible) {
      final n = a.quantiteRestante;
      final texte = a.epuise ? 'Épuisé' : (n == 1 ? 'Plus qu’une pièce' : 'Plus que $n pièces');
      return Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(a.epuise ? Icons.remove_shopping_cart_outlined : Icons.warning_amber_rounded,
            size: 14, color: vally.attention),
        const SizedBox(width: 5),
        Flexible(
          child: Text(texte,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: petit?.copyWith(color: vally.attention, fontWeight: FontWeight.w600)),
        ),
      ]);
    }
    return Text('Il en reste ${a.quantiteRestante} sur ${a.quantiteAchetee}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: petit?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]));
  }
}

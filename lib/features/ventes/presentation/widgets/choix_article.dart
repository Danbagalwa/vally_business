import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/format/montant.dart';
import '../../../../core/rayon.dart';
import '../../../../core/widgets/elements.dart';
import '../../../../core/widgets/montant_texte.dart';
import '../../../../core/widgets/page_erreur.dart';
import '../../../../theme/app_theme.dart';
import '../../../stock/data/stock_repository.dart';
import '../../../stock/domain/article.dart';
import '../../../stock/presentation/widgets/article_tuile.dart';
import '../../../stock/presentation/widgets/photo_article.dart';

/// Feuille de choix d'un article en stock (articles épuisés ou déjà
/// dans la vente exclus).
Future<Article?> choisirArticle(
  BuildContext context, {
  required Devise devise,
  required Set<String> dejaChoisis,
}) {
  return showModalBottomSheet<Article>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (context, defilement) => _ListeArticles(
        devise: devise,
        dejaChoisis: dejaChoisis,
        defilement: defilement,
      ),
    ),
  );
}

class _ListeArticles extends ConsumerStatefulWidget {
  const _ListeArticles({
    required this.devise,
    required this.dejaChoisis,
    required this.defilement,
  });

  final Devise devise;
  final Set<String> dejaChoisis;
  final ScrollController defilement;

  @override
  ConsumerState<_ListeArticles> createState() => _ListeArticlesState();
}

class _ListeArticlesState extends ConsumerState<_ListeArticles> {
  String _recherche = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              VallySpace.s4, 0, VallySpace.s4, VallySpace.s2),
          child: TextField(
            autofocus: false,
            onChanged: (v) => setState(() => _recherche = v),
            decoration: const InputDecoration(
              hintText: 'Rechercher un article',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: ref.watch(articlesRayonProvider).when(
                loading: () => const ListeSquelette(avecResume: false, lignes: 8),
                error: (e, _) => PageErreur(
                    erreur: e,
                    onReessayer: () => ref.invalidate(articlesProvider)),
                data: (tous) {
                  final dispo = filtrerArticles(
                    tous.where((a) =>
                        !a.epuise && !widget.dejaChoisis.contains(a.id)).toList(),
                    recherche: _recherche,
                  );
                  if (dispo.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(VallySpace.s6),
                        child: Text(
                          'Aucun article disponible. Ajoute du stock dans l’onglet Stock.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    controller: widget.defilement,
                    padding: const EdgeInsets.all(VallySpace.s4),
                    itemCount: dispo.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: VallySpace.s2),
                    itemBuilder: (context, i) {
                      final a = dispo[i];
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          onTap: () => Navigator.pop(context, a),
                          leading: PhotoArticle(chemin: a.photoChemin, taille: 44),
                          title: Text(a.nom,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.description,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              BadgeStock(article: a),
                            ],
                          ),
                          trailing: MontantTexte(a.prixVenteHabituel,
                              devise: widget.devise),
                        ),
                      );
                    },
                  );
                },
              ),
        ),
      ],
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format/montant.dart';
import '../../../core/rayon.dart';
import '../../../core/format/texte.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/carnet.dart';
import '../../../core/widgets/elements.dart';
import '../../../core/widgets/page_erreur.dart';
import '../../../core/widgets/page_vide.dart';
import '../../../theme/app_theme.dart';
import '../../boutique/data/boutique_repository.dart';
import '../data/stock_repository.dart';
import '../domain/article.dart';
import 'widgets/article_tuile.dart';
import 'widgets/feuille_rachat.dart';
import 'widgets/photo_article.dart';

/// Réapprovisionner : on choisit l'article racheté, puis on dit combien et
/// à quel prix. Pensé pour le retour du marché : plusieurs à la suite,
/// chaque article racheté reste marqué. Un article introuvable se crée.
class ReapprovisionnementPage extends ConsumerStatefulWidget {
  const ReapprovisionnementPage({super.key, this.recherche});

  /// Recherche de départ (ex. : nom tapé dans « Nouvel article »).
  final String? recherche;

  @override
  ConsumerState<ReapprovisionnementPage> createState() => _ReapprovisionnementPageState();
}

class _ReapprovisionnementPageState extends ConsumerState<ReapprovisionnementPage> {
  late final _recherche = TextEditingController(text: widget.recherche);

  /// Pièces rachetées depuis l'ouverture de la page, par article.
  final _rachetes = <String, int>{};

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  Future<void> _racheter(Article a) async {
    final r = await racheterArticle(context, ref, a);
    if (r != null && mounted) {
      setState(() => _rachetes.update(a.id, (n) => n + r.quantite, ifAbsent: () => r.quantite));
    }
  }

  void _creer(String nom) => context.pushReplacement(
      nom.trim().isEmpty ? Routes.nouvelArticle : '${Routes.nouvelArticle}?nom=${Uri.encodeQueryComponent(nom.trim())}');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final devise = ref.watch(boutiqueActiveProvider).devise;
    final articles = ref.watch(articlesRayonProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Réapprovisionner'), bottom: const BarreRayon()),
      body: articles.when(
        skipLoadingOnRefresh: true,
        loading: () => const ListeSquelette(avecResume: false, avecPhrase: true, avecFiltres: false),
        error: (e, _) => PageErreur(erreur: e, onReessayer: () => ref.invalidate(articlesProvider)),
        data: (tous) {
          if (tous.isEmpty) {
            return PageVide(
              icone: Icons.inventory_2_outlined,
              titre: 'Rien à réapprovisionner',
              message: 'Ajoute d’abord tes articles : tu pourras ensuite les racheter ici.',
              action: FilledButton(onPressed: () => _creer(''), child: const Text('Nouvel article')),
            );
          }
          final recherche = _recherche.text;
          final visibles = filtrerArticles(tous, recherche: recherche);
          final aRacheter = visibles.where((a) => a.epuise || a.stockFaible).toList();
          final autres = visibles.where((a) => !a.epuise && !a.stockFaible).toList();
          final total = _rachetes.values.fold<int>(0, (s, n) => s + n);

          return ListView(
            padding: const EdgeInsets.fromLTRB(VallySpace.s4, 4, VallySpace.s4, 32),
            children: [
              PhraseAvecChiffres(total == 0
                  ? 'Touche l’article que tu as racheté. Tu peux en faire plusieurs à la suite.'
                  : 'Déjà ${pieces(total)} de plus en stock. Continue, ou reviens au stock quand tu as fini.'),
              const SizedBox(height: 12),
              TextField(
                controller: _recherche,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Chercher un article',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: recherche.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Effacer',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(_recherche.clear),
                        ),
                ),
              ),
              if (visibles.isEmpty) ...[
                const SizedBox(height: 28),
                Text('Aucun article ne correspond.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 6),
                // Pas encore en boutique : on le crée, avec le nom déjà tapé.
                Center(
                  child: TextButton.icon(
                    onPressed: () => _creer(recherche),
                    icon: const Icon(Icons.add_rounded),
                    label: Text('Créer « ${recherche.trim()} »', maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ] else ...[
                if (aRacheter.isNotEmpty) ...[
                  EnTeteGroupe(titre: 'À racheter', detail: Text('${aRacheter.length}')),
                  _Liste(articles: aRacheter, devise: devise, rachetes: _rachetes, onTap: _racheter),
                ],
                if (autres.isNotEmpty) ...[
                  EnTeteGroupe(
                    titre: aRacheter.isEmpty ? 'Tes articles' : 'Les autres',
                    detail: Text('${autres.length}'),
                  ),
                  _Liste(articles: autres, devise: devise, rachetes: _rachetes, onTap: _racheter),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Liste extends StatelessWidget {
  const _Liste({required this.articles, required this.devise, required this.rachetes, required this.onTap});

  final List<Article> articles;
  final Devise devise;
  final Map<String, int> rachetes;
  final void Function(Article) onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        for (final (i, a) in articles.indexed) ...[
          if (i > 0) const TraitRegistre(retrait: 72),
          _LigneArticle(article: a, rachete: rachetes[a.id], onTap: () => onTap(a)),
        ],
      ]),
    );
  }
}

/// Une ligne : photo, nom, ce qu'il en reste ; à droite « + » pour racheter,
/// ou ce qui vient d'être racheté (en vert).
class _LigneArticle extends StatelessWidget {
  const _LigneArticle({required this.article, required this.rachete, required this.onTap});

  final Article article;

  /// Pièces rachetées depuis l'ouverture de la page (null : rien).
  final int? rachete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final vally = theme.extension<VallyColors>()!;
    final a = article;
    final n = rachete;
    return Semantics(
      button: true,
      label: 'Racheter ${a.nom}',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(children: [
            PhotoArticle(chemin: a.photoChemin, taille: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.nom,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text([a.description, if (a.pourEnfant) 'Enfant'].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 12.5)),
                const SizedBox(height: 3),
                BadgeStock(article: a),
              ]),
            ),
            const SizedBox(width: 8),
            if (n != null)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_rounded, size: 18, color: vally.benefice),
                const SizedBox(width: 2),
                Text('+ $n',
                    style: theme.textTheme.bodyLarge?.copyWith(color: vally.benefice, fontWeight: FontWeight.w700)),
              ])
            else
              Icon(Icons.add_rounded, color: scheme.primary),
          ]),
        ),
      ),
    );
  }
}

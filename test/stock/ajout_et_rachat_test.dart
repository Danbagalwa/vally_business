import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vally_business/core/format/montant.dart';
import 'package:vally_business/core/router/routes.dart';
import 'package:vally_business/features/auth/data/auth_repository.dart';
import 'package:vally_business/features/boutique/data/boutique_repository.dart';
import 'package:vally_business/features/stock/data/stock_repository.dart';
import 'package:vally_business/features/stock/domain/article.dart';
import 'package:vally_business/features/stock/presentation/article_form_page.dart';
import 'package:vally_business/features/stock/presentation/reapprovisionnement_page.dart';
import 'package:vally_business/features/stock/presentation/stock_page.dart';
import 'package:vally_business/theme/app_theme.dart';

import 'donnees.dart';

class _FauxAuth implements AuthRepository {
  @override
  User? get utilisateurActuel => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FauxStock implements StockRepository {
  _FauxStock(this.articles);

  final List<Article> articles;
  final rachats = <(String, int)>[];

  @override
  Future<List<Article>> lister() async => articles;

  @override
  Future<List<Achat>> achats(String articleId) async => const [];

  @override
  Future<double> reapprovisionner({
    required String articleId,
    required int quantite,
    required double prixSaisi,
    required Devise devise,
    required DateTime date,
    String? fournisseur,
  }) async {
    rachats.add((articleId, quantite));
    return prixSaisi;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Presque épuisée (1 sur 6) : « À racheter ».
Article _robe() => Article.fromJson(ligneVStock(id: 'robe', quantiteAchetee: 6, quantiteVendue: 5));

/// Bien en stock : « Les autres ».
Article _chemise() => Article.fromJson(
    ligneVStock(id: 'chemise', nom: 'Chemise wax', categorie: 'Chemise', quantiteAchetee: 10, quantiteVendue: 2));

/// Les mêmes routes que l'appli pour le stock.
Future<GoRouter> _ouvrir(WidgetTester tester, _FauxStock depot, {String depart = Routes.stock}) async {
  tester.view.physicalSize = const Size(360, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final routeur = GoRouter(initialLocation: depart, routes: [
    GoRoute(path: Routes.stock, builder: (_, _) => const StockPage(), routes: [
      GoRoute(path: 'nouveau', builder: (_, s) => ArticleFormPage(nomPropose: s.uri.queryParameters['nom'])),
      GoRoute(
          path: 'reapprovisionner',
          builder: (_, s) => ReapprovisionnementPage(recherche: s.uri.queryParameters['q'])),
      GoRoute(path: ':id', builder: (_, s) => ArticleFormPage(articleId: s.pathParameters['id'])),
    ]),
  ]);
  await tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [
      authRepositoryProvider.overrideWithValue(_FauxAuth()),
      utilisateurIdProvider.overrideWith((ref) => Stream.value('user-1')),
      boutiqueProvider.overrideWith((ref) async => boutiqueTest),
      stockRepositoryProvider.overrideWithValue(depot),
    ],
    child: Consumer(
      builder: (context, ref, _) => ref.watch(boutiqueProvider).hasValue
          ? MaterialApp.router(theme: VallyTheme.light, routerConfig: routeur)
          : const SizedBox.shrink(),
    ),
  ));
  await tester.pumpAndSettle();
  return routeur;
}

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  testWidgets('« + » du stock : nouvel article et réapprovisionnement sont deux chemins', (tester) async {
    await _ouvrir(tester, _FauxStock([_robe(), _chemise()]));
    await tester.tap(find.byTooltip('Ajouter au stock'));
    await tester.pumpAndSettle();
    expect(find.text('Nouvel article'), findsOneWidget);
    expect(find.text('Réapprovisionner'), findsOneWidget);

    await tester.tap(find.text('Réapprovisionner'));
    await tester.pumpAndSettle();
    expect(find.byType(ReapprovisionnementPage), findsOneWidget);
    expect(find.text('À racheter'), findsOneWidget);
  });

  testWidgets('stock vide : « + » ouvre directement le nouvel article', (tester) async {
    await _ouvrir(tester, _FauxStock(const []));
    await tester.tap(find.byTooltip('Ajouter au stock'));
    await tester.pumpAndSettle();
    expect(find.byType(ArticleFormPage), findsOneWidget);
    expect(find.text('Combien en as-tu acheté ?'), findsOneWidget);
  });

  testWidgets('réapprovisionner : à racheter d’abord, plusieurs à la suite, chacun marqué', (tester) async {
    final depot = _FauxStock([_chemise(), _robe()]);
    await _ouvrir(tester, depot, depart: Routes.reapprovisionner);
    expect(tester.getTopLeft(find.text('Robe pagne fleurie')).dy,
        lessThan(tester.getTopLeft(find.text('Chemise wax')).dy));

    Future<void> racheter(String nom, String quantite) async {
      await tester.tap(find.text(nom));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Combien de pièces as-tu rachetées ?'), quantite);
      await tester.tap(find.text('Ajouter au stock'));
      await tester.pumpAndSettle();
    }

    await racheter('Robe pagne fleurie', '10');
    await racheter('Chemise wax', '4');
    expect(depot.rachats, [('robe', 10), ('chemise', 4)]);
    expect(find.text('+ 10'), findsOneWidget);
    expect(find.text('+ 4'), findsOneWidget);
    expect(find.textContaining('Déjà 14'), findsOneWidget);
  });

  testWidgets('article introuvable : on le crée, avec le nom déjà tapé', (tester) async {
    await _ouvrir(tester, _FauxStock([_robe()]), depart: Routes.reapprovisionner);
    await tester.enterText(find.byType(TextField).first, 'Pantalon jean');
    await tester.pumpAndSettle();
    expect(find.text('Aucun article ne correspond.'), findsOneWidget);

    await tester.tap(find.text('Créer « Pantalon jean »'));
    await tester.pumpAndSettle();
    expect(find.byType(ArticleFormPage), findsOneWidget);
    expect(find.byType(ReapprovisionnementPage), findsNothing); // remplacée, pas empilée
    final nom = tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Nom'));
    expect(nom.controller!.text, 'Pantalon jean');
  });

  testWidgets('nouvel article qui existe déjà : on propose de le réapprovisionner', (tester) async {
    final depot = _FauxStock([_robe()]);
    await _ouvrir(tester, depot, depart: Routes.nouvelArticle);
    // Sans tenir compte des majuscules ni des accents.
    await tester.enterText(find.widgetWithText(TextFormField, 'Nom'), 'robe PAGNE fleurie');
    await tester.pumpAndSettle();
    expect(find.textContaining('Tu as déjà « Robe pagne fleurie » (taille M)'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Réapprovisionner'));
    await tester.pumpAndSettle();
    expect(find.text('Racheter « Robe pagne fleurie »'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Combien de pièces as-tu rachetées ?'), '3');
    // La feuille est au-dessus du formulaire : son bouton est le dernier.
    await tester.tap(find.widgetWithText(FilledButton, 'Ajouter au stock').last);
    await tester.pumpAndSettle();
    expect(depot.rachats, [('robe', 3)]);
    // Rien à créer : retour au stock.
    expect(find.byType(ArticleFormPage), findsNothing);
    expect(find.byType(StockPage), findsOneWidget);
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vally_business/core/erreurs.dart';
import 'package:vally_business/core/format/montant.dart';
import 'package:vally_business/core/widgets/champ_montant.dart';
import 'package:vally_business/features/auth/data/auth_repository.dart';
import 'package:vally_business/features/boutique/data/boutique_repository.dart';
import 'package:vally_business/features/stock/data/stock_repository.dart';
import 'package:vally_business/features/stock/domain/article.dart';
import 'package:vally_business/features/stock/presentation/article_form_page.dart';
import 'package:vally_business/theme/app_theme.dart';

import 'donnees.dart';

final _e = String.fromCharCode(0xA0); // espace insécable

class _FauxAuth implements AuthRepository {
  @override
  User? get utilisateurActuel => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Faux dépôt : retient ce que l'écran demande, sans toucher à Supabase.
class _FauxStock implements StockRepository {
  _FauxStock(this.articles, {this.historique = const []});

  final List<Article> articles;
  final List<Achat> historique;
  final rachats = <(String, int, double, Devise)>[];
  final retraits = <String>[];
  final modifications = <ArticleSaisie>[];

  @override
  Future<List<Article>> lister() async => articles;

  @override
  Future<List<Achat>> achats(String articleId) async => historique;

  @override
  Future<double> reapprovisionner({
    required String articleId,
    required int quantite,
    required double prixSaisi,
    required Devise devise,
    required DateTime date,
    String? fournisseur,
  }) async {
    rachats.add((articleId, quantite, prixSaisi, devise));
    return prixSaisi;
  }

  @override
  Future<void> annulerDernierRachat(String articleId) async => retraits.add(articleId);

  @override
  Future<void> modifier(String id, ArticleSaisie saisie) async => modifications.add(saisie);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Robe achetée deux fois : 10 à 10 000, puis 6 à 12 000 ; 14 vendues.
/// Coût moyen 11 666,67 (pas un nombre rond : c'est le piège de l'arrondi).
Article _robeRachetee() => Article.fromJson(ligneVStock(
      id: 'robe',
      nom: 'Robe pagne fleurie',
      quantiteAchetee: 16,
      quantiteVendue: 14,
      prixAchat: 11666.67,
    )
      ..['nb_achats'] = 2
      ..['total_approvisionne'] = 172000);

Achat _achat(String id, String date, int q, num prix, {bool rachat = false, String? fournisseur}) =>
    Achat.fromJson({
      'id': id, 'date_appro': date, 'quantite': q, 'prix_achat': prix, 'fournisseur': fournisseur,
      'prix_moyen_avant': rachat ? 10000 : null, 'devise_saisie': null, 'montant_saisi': null,
      'taux_change': null, 'created_at': '${date}T10:00:00Z',
    });

Future<void> _ouvrirFiche(WidgetTester tester, _FauxStock depot, String articleId) async {
  tester.view.physicalSize = const Size(360, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final routeur = GoRouter(initialLocation: '/article', routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => const Scaffold(body: Text('Stock')),
      routes: [GoRoute(path: 'article', builder: (_, _) => ArticleFormPage(articleId: articleId))],
    ),
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
}

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  group('Coût moyen après un rachat', () {
    test('2 pièces à 10 000 + 10 rachetées à 12 000 → 11 666,67', () {
      expect(coutMoyenApresRachat(restant: 2, coutActuel: 10000, quantite: 10, prix: 12000), 11666.67);
    });
    test('épuisé : le coût est celui du rachat ; même prix : rien ne change', () {
      expect(coutMoyenApresRachat(restant: 0, coutActuel: 10000, quantite: 5, prix: 12000), 12000);
      expect(coutMoyenApresRachat(restant: -1, coutActuel: 10000, quantite: 5, prix: 12000), 12000);
      expect(coutMoyenApresRachat(restant: 3, coutActuel: 10000, quantite: 3, prix: 10000), 10000);
    });
  });

  test('où en est l’article, en une phrase', () {
    expect(phraseResteArticle(article(quantiteAchetee: 10, quantiteVendue: 8)), 'Il en reste 2 sur 10.');
    expect(phraseResteArticle(article(quantiteAchetee: 1, quantiteVendue: 1)),
        'Épuisé : la seule pièce est vendue ou réservée.');
    expect(phraseResteArticle(article(quantiteAchetee: 4, quantiteVendue: 4)),
        'Épuisé : les 4 pièces sont vendues ou réservées.');
  });

  test('achats : premier achat ou rachat ; nb_achats absent = 1 (base pas à jour)', () {
    expect(_achat('1', '2026-11-02', 10, 10000).estRachat, isFalse);
    expect(_achat('2', '2026-11-19', 6, 12000, rachat: true).estRachat, isTrue);
    expect(article().nbAchats, 1);
    expect(article().dejaRachete, isFalse);
    expect(_robeRachetee().dejaRachete, isTrue);
  });

  test('fonction pas encore créée en base : on le dit clairement', () {
    expect(messageErreur(const PostgrestException(message: 'x', code: 'PGRST202')),
        contains('mise à jour de la base'));
  });

  for (final (nom, theme) in [('clair', VallyTheme.light), ('sombre', VallyTheme.dark)]) {
    testWidgets('nouvel article : toute la page à 360 px, et la marge en une phrase ($nom)', (tester) async {
      tester.view.physicalSize = const Size(360, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FauxAuth()),
          utilisateurIdProvider.overrideWith((ref) => Stream.value('user-1')),
          boutiqueProvider.overrideWith((ref) async => boutiqueTest),
          stockRepositoryProvider.overrideWithValue(_FauxStock(const [])),
        ],
        child: MaterialApp(
          theme: theme,
          home: Consumer(
            builder: (context, ref, _) =>
                ref.watch(boutiqueProvider).hasValue ? const ArticleFormPage() : const SizedBox.shrink(),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Combien en as-tu acheté ?'), findsOneWidget);
      expect(find.text('Racheter'), findsNothing); // rien à racheter avant d'exister

      await tester.enterText(find.widgetWithText(TextFormField, 'Combien en as-tu acheté ?'), '10');
      Finder montant(String libelle) => find.descendant(
          of: find.widgetWithText(ChampMontant, libelle), matching: find.byType(TextField));
      await tester.enterText(montant('Prix d’achat d’une pièce'), '10000');
      await tester.enterText(montant('Prix de vente habituel'), '15000');
      await tester.pumpAndSettle();
      expect(find.textContaining('si tu vends les 10'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('racheter depuis la fiche : la feuille dit ce qui va changer', (tester) async {
    final robe = Article.fromJson(ligneVStock(id: 'robe', quantiteAchetee: 10, quantiteVendue: 8));
    final depot = _FauxStock([robe]);
    await _ouvrirFiche(tester, depot, 'robe');

    expect(find.text('Il en reste 2'), findsOneWidget);
    await tester.tap(find.text('Racheter'));
    await tester.pumpAndSettle();
    expect(find.text('Racheter « Robe pagne fleurie »'), findsOneWidget);
    expect(find.text('Il en reste 2 sur 10.'), findsOneWidget);

    // Prix pré-rempli avec le coût actuel (10 000) ; on en rachète 10.
    await tester.enterText(find.widgetWithText(TextFormField, 'Combien de pièces as-tu rachetées ?'), '10');
    await tester.pumpAndSettle();
    expect(find.text('Tu auras 12${_e}pièces en boutique.'), findsOneWidget);

    await tester.tap(find.text('Ajouter au stock'));
    await tester.pumpAndSettle();
    expect(depot.rachats, [('robe', 10, 10000.0, Devise.cdf)]);
  });

  testWidgets('article déjà racheté : historique, coût moyen, retrait du dernier rachat', (tester) async {
    final depot = _FauxStock([_robeRachetee()], historique: [
      _achat('a2', '2026-11-19', 6, 12000, rachat: true, fournisseur: 'Grossiste Kin'),
      _achat('a1', '2026-11-02', 10, 10000),
    ]);
    await _ouvrirFiche(tester, depot, 'robe');

    expect(find.text('Investi en tout'), findsOneWidget);
    expect(find.textContaining('Rachat · Grossiste Kin'), findsOneWidget);
    expect(find.text('Premier achat'), findsOneWidget);
    expect(find.textContaining('Une pièce te revient en moyenne à'), findsOneWidget);
    // Quantité et prix ne se corrigent plus à la main.
    expect(find.widgetWithText(TextFormField, 'Quantité achetée'), findsNothing);

    await tester.tap(find.text('Retirer ce rachat'));
    await tester.pumpAndSettle();
    expect(find.text('Retirer ce rachat ?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Retirer'));
    await tester.pumpAndSettle();
    expect(depot.retraits, ['robe']);
  });

  testWidgets('racheter un article déjà racheté propose le prix du dernier achat, pas la moyenne', (tester) async {
    final depot = _FauxStock([_robeRachetee()], historique: [
      _achat('a2', '2026-11-19', 6, 12000, rachat: true),
      _achat('a1', '2026-11-02', 10, 10000),
    ]);
    await _ouvrirFiche(tester, depot, 'robe');
    await tester.tap(find.text('Racheter'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Combien de pièces as-tu rachetées ?'), '4');
    await tester.pumpAndSettle();
    // 2 en boutique à 11 666,67 + 4 à 12 000 → coût moyen 11 888,89, affiché « avant / après ».
    expect(find.textContaining('Coût moyen d’une pièce'), findsOneWidget);
    await tester.tap(find.text('Ajouter au stock'));
    await tester.pumpAndSettle();
    expect(depot.rachats, [('robe', 4, 12000.0, Devise.cdf)]);
  });

  testWidgets('enregistrer un article racheté ne renvoie ni quantité ni prix arrondis', (tester) async {
    final depot = _FauxStock([_robeRachetee()], historique: [
      _achat('a2', '2026-11-19', 6, 12000, rachat: true),
      _achat('a1', '2026-11-02', 10, 10000),
    ]);
    await _ouvrirFiche(tester, depot, 'robe');

    await tester.enterText(find.widgetWithText(TextFormField, 'Nom'), 'Robe pagne fleurie bleue');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(depot.modifications, hasLength(1));
    final s = depot.modifications.single;
    expect(s.nom, 'Robe pagne fleurie bleue');
    // 11 666,67 s'affiche « 11 667 » en CDF : c'est bien la valeur exacte qui repart.
    expect(s.prixAchat, 11666.67);
    expect(s.quantiteAchetee, 16);
    // Retour à la liste après l'enregistrement.
    expect(find.text('Stock'), findsOneWidget);
  });
}

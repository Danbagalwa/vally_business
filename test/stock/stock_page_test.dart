import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vally_business/core/format/montant.dart';
import 'package:vally_business/core/widgets/champ_montant.dart';
import 'package:vally_business/features/auth/data/auth_repository.dart';
import 'package:vally_business/features/boutique/data/boutique_repository.dart';
import 'package:vally_business/features/stock/data/stock_repository.dart';
import 'package:vally_business/features/stock/domain/article.dart';
import 'package:vally_business/features/stock/presentation/stock_page.dart';
import 'package:vally_business/theme/app_theme.dart';

import 'donnees.dart';

/// Compte factice : aucun appel à Supabase pendant les tests.
class _FauxAuth implements AuthRepository {
  @override
  User? get utilisateurActuel => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _ouvrirStock(WidgetTester tester, List<Article> articles) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(_FauxAuth()),
      utilisateurIdProvider.overrideWith((ref) => Stream.value('user-1')),
      boutiqueProvider.overrideWith((ref) async => boutiqueTest),
      articlesProvider.overrideWith((ref) async => articles),
    ],
    child: MaterialApp(
      theme: VallyTheme.light,
      home: Consumer(
        // Comme la PorteBoutique : la page s'affiche une fois la boutique chargée.
        builder: (context, ref, _) => ref.watch(boutiqueProvider).hasValue
            ? const StockPage()
            : const SizedBox.shrink(),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  testWidgets('stock vide : invite à ajouter un article', (tester) async {
    await _ouvrirStock(tester, const []);
    expect(find.text('Aucun article pour l’instant'), findsOneWidget);
    expect(find.text('Ajouter un article'), findsOneWidget);
  });

  testWidgets('liste : résumé, alertes, filtres catégorie / enfant, recherche',
      (tester) async {
    final pyjama = Article.fromJson(
        ligneVStock(nom: 'Pyjama ourson', categorie: 'Ensemble', taille: '2 ans', quantiteAchetee: 3)
          ..['pour_enfant'] = true);
    await _ouvrirStock(tester, [
      article(nom: 'Robe pagne fleurie', quantiteAchetee: 5, quantiteVendue: 3),
      article(
          nom: 'Chemise wax',
          categorie: 'Chemise',
          quantiteAchetee: 2,
          quantiteVendue: 2),
      article(nom: 'Robe de soirée', quantiteAchetee: 4, quantiteVendue: 0),
      pyjama,
    ]);

    // Valeur restante : (2 + 0 + 4 + 3) × 10 000 = 90 000 CDF.
    expect(find.text('90 000 CDF'), findsOneWidget);
    expect(find.text('Plus que 2 en stock'), findsOneWidget);
    expect(find.text('Épuisé'), findsOneWidget);
    expect(find.text('4 / 4 en stock'), findsOneWidget);
    expect(find.text('1 épuisé · 1 bientôt épuisé'), findsOneWidget);
    expect(find.text('Enfant'), findsWidgets);

    await tester.tap(find.widgetWithText(FilterChip, 'Enfant'));
    await tester.pumpAndSettle();
    expect(find.text('Pyjama ourson'), findsOneWidget);
    expect(find.text('Robe de soirée'), findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, 'Tous'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Chemise'));
    await tester.pumpAndSettle();
    expect(find.text('Chemise wax'), findsOneWidget);
    expect(find.text('Robe de soirée'), findsNothing);

    // Retaper la catégorie active la retire.
    await tester.tap(find.widgetWithText(FilterChip, 'Chemise'));
    await tester.tap(find.byTooltip('Rechercher'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'soiree');
    await tester.pumpAndSettle();
    expect(find.text('Robe de soirée'), findsOneWidget);
    expect(find.text('Robe pagne fleurie'), findsNothing);
  });

  testWidgets('ChampMontant : saisie en USD convertie en CDF', (tester) async {
    final controller = MontantSaisieController(devise: Devise.cdf);
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: VallyTheme.light,
      home: Scaffold(
        body: ChampMontant(
          controller: controller,
          label: 'Prix d’achat unitaire',
          deviseReference: Devise.cdf,
          tauxUsdVersCdf: 2800,
        ),
      ),
    ));
    await tester.tap(find.text('USD'));
    await tester.pump();
    expect(controller.devise, Devise.usd);

    await tester.enterText(find.byType(TextFormField), '10,5');
    await tester.pump();
    expect(controller.enReference(Devise.cdf, 2800), 29400);
    expect(find.textContaining('≈ 29 400 CDF'), findsOneWidget);
  });
}

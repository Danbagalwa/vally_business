import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vally_business/features/auth/data/auth_repository.dart';
import 'package:vally_business/features/boutique/data/boutique_repository.dart';
import 'package:vally_business/features/stock/data/stock_repository.dart';
import 'package:vally_business/features/tableau_de_bord/data/tableau_de_bord_repository.dart';
import 'package:vally_business/features/tableau_de_bord/domain/indicateurs.dart';
import 'package:vally_business/features/tableau_de_bord/presentation/tableau_de_bord_page.dart';
import 'package:vally_business/features/ventes/data/ventes_repository.dart';
import 'package:vally_business/features/ventes/domain/commande.dart';
import 'package:vally_business/theme/app_theme.dart';

import '../stock/donnees.dart';
import '../ventes/donnees_ventes.dart';

/// La liste principale (et non la rangée horizontale des périodes).
final _listeVerticale = find.byWidgetPredicate(
    (w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;

class _FauxAuth implements AuthRepository {
  @override
  User? get utilisateurActuel => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _ouvrir(WidgetTester tester, ThemeData theme) async {
  // Largeur d'un petit téléphone.
  tester.view.physicalSize = const Size(360, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final aujourdhui = DateTime.now();
  final iso = '${aujourdhui.year}-${aujourdhui.month.toString().padLeft(2, '0')}-01';
  final vente = ligneVCommandes(total: 1250000, paye: 800000)..['date_commande'] = iso;

  await tester.pumpWidget(ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(_FauxAuth()),
      utilisateurIdProvider.overrideWith((ref) => Stream.value('user-1')),
      boutiqueProvider.overrideWith((ref) async => boutiqueTest),
      articlesProvider.overrideWith((ref) async => [
            article(nom: 'Robe pagne fleurie', quantiteAchetee: 5, quantiteVendue: 3),
          ]),
      commandesProvider.overrideWith((ref) async => [Commande.fromJson(vente)]),
      indicateursPrecedentsProvider.overrideWith((ref) async => const IndicateursPeriode(
            totalApprovisionne: 1000000, chiffreAffaires: 1000000, coutVentes: 700000,
            benefice: 300000, totalEncaisse: 900000, resteDu: 100000, gainAuDessus: 0,
            coutRemises: 20000, nbCommandes: 2, piecesVendues: 4,
          )),
      indicateursPeriodeProvider.overrideWith((ref) async => const IndicateursPeriode(
            totalApprovisionne: 3450000,
            chiffreAffaires: 1250000,
            coutVentes: 900000,
            benefice: 350000,
            totalEncaisse: 800000,
            resteDu: 450000,
            gainAuDessus: 25000,
            coutRemises: 12000,
            nbCommandes: 1,
            piecesVendues: 3,
          )),
      indicateursActuelsProvider.overrideWith((ref) async => const IndicateursActuels(
            valeurStockRestant: 2550000,
            piecesEnStock: 42,
            articlesEpuises: 1,
            beneficeRealise: 350000,
            beneficeVerse: 100000,
            beneficeDisponible: 250000,
            resteDu: 450000,
          )),
      articlesVendusProvider.overrideWith((ref) async => const [
            ArticleVendu(
                articleId: 'a1',
                nom: 'Robe pagne fleurie',
                description: 'Robe · M',
                quantite: 3,
                chiffreAffaires: 1250000,
                benefice: 350000),
          ]),
    ],
    child: MaterialApp(
      theme: theme,
      home: Consumer(
        builder: (context, ref, _) => ref.watch(boutiqueProvider).hasValue
            ? const TableauDeBordPage()
            : const SizedBox.shrink(),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  for (final (nom, theme) in [('clair', VallyTheme.light), ('sombre', VallyTheme.dark)]) {
    testWidgets('s’affiche sans débordement à 360 px (thème $nom)', (tester) async {
      await _ouvrir(tester, theme);
      expect(tester.takeException(), isNull);
      expect(find.text('Bénéfice réalisé'), findsWidgets);
      expect(find.text('+ 350 000 CDF'), findsWidgets);
      expect(find.text('Bénéfice par mois'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('NE PARTENT PAS'), 300, scrollable: _listeVerticale);
      expect(tester.takeException(), isNull);
      expect(find.text('LES PLUS VENDUS'), findsOneWidget);
    });
  }

  testWidgets('le graphique bascule en vue tableau', (tester) async {
    await _ouvrir(tester, VallyTheme.light);
    await tester.scrollUntilVisible(find.byTooltip('Voir en tableau'), 300, scrollable: _listeVerticale);
    await tester.tap(find.byTooltip('Voir en tableau'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Voir le graphique'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

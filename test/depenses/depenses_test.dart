import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vally_business/core/format/montant.dart';
import 'package:vally_business/features/auth/data/auth_repository.dart';
import 'package:vally_business/features/boutique/data/boutique_repository.dart';
import 'package:vally_business/features/depenses/data/depenses_repository.dart';
import 'package:vally_business/features/depenses/domain/mouvement.dart';
import 'package:vally_business/features/depenses/presentation/depenses_page.dart';
import 'package:vally_business/features/tableau_de_bord/data/tableau_de_bord_repository.dart';
import 'package:vally_business/features/tableau_de_bord/domain/indicateurs.dart';
import 'package:vally_business/theme/app_theme.dart';

import '../stock/donnees.dart';

final _ceMois = DateTime.now();
String _date(int jour) =>
    '${_ceMois.year}-${_ceMois.month.toString().padLeft(2, '0')}-${jour.toString().padLeft(2, '0')}';

Mouvement _m(String id, String type, num montant, String categorie,
        {String jour = '01', String source = 'manuel', String? note}) =>
    Mouvement.fromJson({
      'id': id, 'type': type, 'montant': montant, 'categorie': categorie,
      'date_mouvement': _date(int.parse(jour)), 'note': note, 'source': source,
      'devise_saisie': 'CDF', 'montant_saisi': montant, 'taux_change': null,
      'created_at': '${_date(int.parse(jour))}T10:00:00Z',
    });

final _mouvements = [
  _m('1', 'entree', 120000, 'Bénéfice boutique', source: 'boutique', note: 'Pour le loyer'),
  _m('2', 'sortie', 80000, 'Loyer'),
  _m('3', 'sortie', 15000, 'Transport'),
  _m('4', 'sortie', 25000, 'Nourriture'),
];

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  group('Bilan et répartition', () {
    test('solde = entrées − sorties', () {
      final b = Bilan.de(_mouvements);
      expect(b.entrees, 120000);
      expect(b.sorties, 120000);
      expect(b.solde, 0);
    });

    test('sorties par catégorie, la plus grosse d’abord, avec la part', () {
      final r = repartitionSorties(_mouvements);
      expect(r.map((p) => p.categorie), ['Loyer', 'Nourriture', 'Transport']);
      expect(r.first.part, closeTo(80000 / 120000, 1e-9));
    });

    test('mouvements du mois, versement de la boutique reconnu', () {
      expect(duMois(_mouvements, _ceMois).length, 4);
      expect(duMois(_mouvements, DateTime(2020, 1)).isEmpty, isTrue);
      expect(_mouvements.first.depuisBoutique, isTrue);
      expect(_mouvements[1].signe, -80000);
    });

    test('saisie : note vide en null, date ISO', () {
      final json = MouvementSaisie(
        type: TypeMouvement.sortie, montantSaisi: 10, devise: Devise.usd,
        categorie: ' Santé ', date: DateTime(2026, 11, 3), note: '  ',
      ).toJson();
      expect(json, {
        'type': 'sortie', 'montant_saisi': 10.0, 'devise_saisie': 'USD',
        'categorie': 'Santé', 'date_mouvement': '2026-11-03', 'note': null,
      });
    });
  });

  for (final (nom, theme) in [('clair', VallyTheme.light), ('sombre', VallyTheme.dark)]) {
    testWidgets('Mes dépenses s’affiche sans débordement à 360 px ($nom)', (tester) async {
      tester.view.physicalSize = const Size(360, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          utilisateurIdProvider.overrideWith((ref) => Stream.value('user-1')),
          boutiqueProvider.overrideWith((ref) async => boutiqueTest),
          mouvementsProvider.overrideWith((ref) async => _mouvements),
          fluxMensuelProvider.overrideWith((ref) async => [
                FluxMensuel(mois: DateTime(_ceMois.year, _ceMois.month), entrees: 120000, sorties: 120000, soldeCumule: 0),
              ]),
          indicateursActuelsProvider.overrideWith((ref) async => const IndicateursActuels(
                valeurStockRestant: 0, piecesEnStock: 0, articlesEpuises: 0,
                beneficeRealise: 350000, beneficeEncaisse: 300000,
                beneficeVerse: 120000, beneficeDisponible: 180000, resteDu: 0,
              )),
        ],
        child: MaterialApp(
          theme: theme,
          home: Consumer(
            builder: (context, ref, _) =>
                ref.watch(boutiqueProvider).hasValue ? const DepensesPage() : const SizedBox.shrink(),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Me verser un bénéfice'), findsOneWidget);
      // Disponible 180 000, en attente 50 000 (ventes pas encore payées).
      expect(find.textContaining('180 000'), findsWidgets);
      expect(find.textContaining('En attente de paiement'), findsOneWidget);
      expect(find.text('Loyer'), findsWidgets);
      expect(find.text('Versé depuis la boutique · Pour le loyer'), findsOneWidget);
    });
  }
}

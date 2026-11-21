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

  group('Le carnet en mots', () {
    final f = FormatMontant.formater;

    test('phrase du mois', () {
      expect(phraseMois(const Bilan(entrees: 206000, sorties: 161000), Devise.cdf, enCours: true),
          'Tu as reçu ${f(206000, Devise.cdf)} et dépensé ${f(161000, Devise.cdf)}.');
      expect(phraseMois(const Bilan(entrees: 0, sorties: 9000), Devise.cdf, enCours: true),
          'Tu as dépensé ${f(9000, Devise.cdf)}.');
      expect(phraseMois(const Bilan(entrees: 5000, sorties: 0), Devise.cdf, enCours: false),
          'Tu as reçu ${f(5000, Devise.cdf)}, sans rien dépenser.');
      expect(phraseMois(const Bilan(entrees: 0, sorties: 0), Devise.cdf, enCours: true),
          'Rien de noté ce mois-ci.');
      expect(phraseMois(const Bilan(entrees: 0, sorties: 0), Devise.cdf, enCours: false),
          'Rien de noté ce mois-là.');
    });

    test('titre et détails d’une ligne (note, montant saisi dans l’autre devise)', () {
      expect(_mouvements.first.titre, 'Bénéfice de la boutique');
      expect(_mouvements.first.details, 'Pour le loyer');
      expect(_mouvements[1].titre, 'Loyer');
      expect(_mouvements[1].details, isNull);
      final cadeau = Mouvement.fromJson({
        'id': 'c', 'type': 'entree', 'montant': 56000, 'categorie': 'Cadeau',
        'date_mouvement': '2026-11-15', 'note': 'Anniversaire', 'source': 'manuel',
        'devise_saisie': 'USD', 'montant_saisi': 20, 'taux_change': 2800,
        'created_at': '2026-11-15T10:00:00Z',
      });
      expect(cadeau.details,
          'Anniversaire · ${f(20, Devise.usd)} au taux de ${f(2800, Devise.cdf)}');
    });
  });

  for (final (nom, theme) in [('clair', VallyTheme.light), ('sombre', VallyTheme.dark)]) {
    testWidgets('Mes dépenses s’affiche sans débordement à 360 px ($nom)', (tester) async {
      await _afficher(tester, theme: theme);
      expect(tester.takeException(), isNull);
      // Ce qu'il te reste : 120 000 reçus, 120 000 dépensés.
      expect(find.text('Il te reste'), findsOneWidget);
      // La boutique : 180 000 disponibles, 50 000 attendent que les clients paient.
      expect(find.text('La boutique peut te verser'), findsOneWidget);
      expect(find.text('Me verser'), findsOneWidget);
      expect(find.textContaining(FormatMontant.nombre(180000, Devise.cdf)), findsWidgets);
      expect(find.textContaining('quand tes clients auront tout payé'), findsOneWidget);
      // Le carnet du mois.
      expect(find.text('Loyer'), findsWidgets);
      expect(find.text('Bénéfice de la boutique'), findsOneWidget);
      expect(find.text('Pour le loyer'), findsOneWidget);
      expect(find.text('Reste du mois'), findsOneWidget);
    });
  }

  testWidgets('supprimer une dépense demande toujours une confirmation', (tester) async {
    final depot = _FauxDepenses();
    await _afficher(tester, depot: depot);

    Future<void> demanderSuppression() async {
      // La ligne du carnet (plus haut, « Loyer » est aussi une barre de « Où part ton argent »).
      await tester.tap(find.text('Loyer').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Supprimer'));
      await tester.pumpAndSettle();
      expect(find.text('Supprimer cette dépense ?'), findsOneWidget);
    }

    await demanderSuppression();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(depot.supprimes, isEmpty);

    await demanderSuppression();
    await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
    await tester.pumpAndSettle();
    expect(depot.supprimes, ['2']);
  });

  testWidgets('bénéfice de la boutique illisible : un message et « Réessayer »', (tester) async {
    await _afficher(tester, benefice: () async => throw Exception('réseau'));
    expect(find.text('Impossible de lire le bénéfice de la boutique.'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
    // Le carnet reste lisible.
    expect(find.text('Il te reste'), findsOneWidget);
  });
}

/// Faux dépôt : retient les suppressions demandées, ne touche à rien d'autre.
class _FauxDepenses implements DepensesRepository {
  final supprimes = <String>[];

  @override
  Future<void> supprimer(String id) async => supprimes.add(id);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _benefice = IndicateursActuels(
  valeurStockRestant: 0, piecesEnStock: 0, articlesEpuises: 0,
  beneficeRealise: 350000, beneficeEncaisse: 300000,
  beneficeVerse: 120000, beneficeDisponible: 180000, resteDu: 0,
);

Future<void> _afficher(
  WidgetTester tester, {
  ThemeData? theme,
  Future<IndicateursActuels> Function()? benefice,
  DepensesRepository? depot,
}) async {
  tester.view.physicalSize = const Size(360, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    // Pas de nouvel essai automatique en test : une erreur reste une erreur.
    retry: (_, _) => null,
    overrides: [
      utilisateurIdProvider.overrideWith((ref) => Stream.value('user-1')),
      boutiqueProvider.overrideWith((ref) async => boutiqueTest),
      mouvementsProvider.overrideWith((ref) async => _mouvements),
      fluxMensuelProvider.overrideWith((ref) async => [
            FluxMensuel(
                mois: DateTime(_ceMois.year, _ceMois.month), entrees: 120000, sorties: 120000, soldeCumule: 0),
          ]),
      indicateursActuelsProvider.overrideWith((ref) => (benefice ?? () async => _benefice)()),
      if (depot != null) depensesRepositoryProvider.overrideWithValue(depot),
    ],
    child: MaterialApp(
      theme: theme ?? VallyTheme.light,
      home: Consumer(
        builder: (context, ref, _) =>
            ref.watch(boutiqueProvider).hasValue ? const DepensesPage() : const SizedBox.shrink(),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

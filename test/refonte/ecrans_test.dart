import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vally_business/core/format/dates.dart';
import 'package:vally_business/features/accueil/presentation/accueil_page.dart';
import 'package:vally_business/features/auth/data/auth_repository.dart';
import 'package:vally_business/features/boutique/data/boutique_repository.dart';
import 'package:vally_business/features/clients/data/clients_repository.dart';
import 'package:vally_business/features/clients/domain/client_resume.dart';
import 'package:vally_business/features/clients/presentation/client_detail_page.dart';
import 'package:vally_business/features/clients/presentation/clients_page.dart';
import 'package:vally_business/features/plus/presentation/plus_page.dart';
import 'package:vally_business/features/stock/data/stock_repository.dart';
import 'package:vally_business/features/ventes/data/ventes_repository.dart';
import 'package:vally_business/features/ventes/domain/commande.dart';
import 'package:vally_business/features/ventes/presentation/commande_detail_page.dart';
import 'package:vally_business/features/ventes/presentation/commandes_page.dart';
import 'package:vally_business/features/ventes/presentation/saisie_vente_page.dart';
import 'package:vally_business/features/ventes/presentation/ventes_page.dart';
import 'package:vally_business/theme/app_theme.dart';

import '../stock/donnees.dart';
import '../ventes/donnees_ventes.dart';

class _FauxAuth implements AuthRepository {
  @override
  User? get utilisateurActuel => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _aujourdhui = FormatDate.iso(DateTime.now());
final _hier = FormatDate.iso(DateTime.now().subtract(const Duration(days: 2)));

final _commandes = [
  Commande.fromJson(ligneVCommandes(id: 'v1', date: _aujourdhui, clientNom: 'Maman Rose Mbuyi Kalonji', total: 1250000)),
  Commande.fromJson(ligneVCommandes(id: 'v2', date: _aujourdhui, clientNom: null, statutPaiement: 'soldee', paye: 22000)),
  Commande.fromJson(ligneVCommandes(
      id: 'k1', type: 'commande', statutLivraison: 'en_attente', date: _hier,
      dateLivraison: _aujourdhui, modeRemise: 'livraison', frais: 3000, total: 25000,
      clientNom: 'Mme Kabila Ngalula')),
  Commande.fromJson(ligneVCommandes(
      id: 'k2', type: 'commande', statutLivraison: 'prete', date: _hier,
      dateLivraison: _hier, modeRemise: 'retrait', statutPaiement: 'non_payee', paye: 0)),
];

final _clients = [
  ClientResume.fromJson({
    'id': 'cl-Maman Rose', 'nom': 'Maman Rose Mbuyi Kalonji', 'telephone': '081 234 5678',
    'nb_achats': 12, 'total_achats': 4250000, 'total_du': 1236000, 'nb_impayes': 1,
    'dernier_achat': _aujourdhui,
  }),
  ClientResume.fromJson({
    'id': 'cl-2', 'nom': 'Papa Jo', 'telephone': null, 'nb_achats': 1, 'total_achats': 9000,
    'total_du': 0, 'nb_impayes': 0, 'dernier_achat': null,
  }),
];

Future<void> _afficher(WidgetTester tester, Widget page, ThemeData theme) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(_FauxAuth()),
      utilisateurIdProvider.overrideWith((ref) => Stream.value('user-1')),
      boutiqueProvider.overrideWith((ref) async => boutiqueTest),
      articlesProvider.overrideWith((ref) async => [
            article(nom: 'Robe pagne fleurie', quantiteAchetee: 5, quantiteVendue: 4),
          ]),
      commandesProvider.overrideWith((ref) async => _commandes),
      clientsResumeProvider.overrideWith((ref) async => _clients),
      clientsProvider.overrideWith((ref) async => const <Client>[]),
      commandeDetailProvider.overrideWith((ref, id) async => CommandeDetail(
            commande: _commandes.firstWhere((c) => c.id == id),
            lignes: [
              LigneCommande.fromJson({
                'id': 'l1', 'article_id': 'a1', 'quantite': 2, 'prix_vendu': 11000,
                'prix_achat_snapshot': 8000, 'prix_habituel_snapshot': 12000,
                'articles': {'nom': 'Ensemble garçon brodé', 'categorie': 'Ensemble', 'taille': '4 ans'},
              }),
            ],
            paiements: [
              Paiement.fromJson({
                'id': 'p1', 'montant': 14000, 'date_paiement': _aujourdhui, 'mode': 'mobile_money',
                'devise_saisie': 'USD', 'montant_saisi': 5, 'taux_change': 2800,
              }),
            ],
          )),
    ],
    child: MaterialApp(
      theme: theme,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('fr', 'FR')],
      locale: const Locale('fr', 'FR'),
      home: Consumer(
        builder: (context, ref, _) =>
            ref.watch(boutiqueProvider).hasValue ? page : const SizedBox.shrink(),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  final ecrans = <String, (Widget, String)>{
    'Accueil': (const AccueilPage(), 'À livrer aujourd’hui'),
    'Ventes': (const VentesPage(), 'Nouvelle vente'),
    'Commandes': (const CommandesPage(), 'Nouvelle commande'),
    'Plus': (const PlusPage(), 'Clients et dettes'),
    'Clients': (const ClientsPage(), 'On te doit '),
    'Fiche client': (const ClientDetailPage(clientId: 'cl-Maman Rose'), 'À encaisser'),
    'Détail commande': (const CommandeDetailPage(commandeId: 'k1'), 'Livraison'),
    'Détail vente': (const CommandeDetailPage(commandeId: 'v1'), 'Paiements'),
    'Nouvelle vente': (const SaisieVentePage(type: TypeCommande.vente), 'Encaisser'),
    'Nouvelle commande': (const SaisieVentePage(type: TypeCommande.commande), 'Livraison'),
  };

  for (final (nomTheme, theme) in [('clair', VallyTheme.light), ('sombre', VallyTheme.dark)]) {
    for (final MapEntry(key: nom, value: (page, texte)) in ecrans.entries) {
      testWidgets('$nom s’affiche sans débordement à 360 px ($nomTheme)', (tester) async {
        await _afficher(tester, page, theme);
        expect(tester.takeException(), isNull);
        expect(find.textContaining(texte), findsWidgets);
      });
    }
  }

  testWidgets('Commandes : « Marquer prête » sur la commande du jour', (tester) async {
    await _afficher(tester, const CommandesPage(), VallyTheme.light);
    expect(find.text('Mme Kabila Ngalula'), findsOneWidget);
    expect(find.text('Marquer prête'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, 'En retard'));
    await tester.pumpAndSettle();
    expect(find.text('Marquer livrée'), findsOneWidget);
  });
}

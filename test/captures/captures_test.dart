// Captures d'écran réalistes (vraies polices, taille d'un TECNO 360 × 806)
// pour relire le design. Ne tourne que sur demande :
//
//   $env:VALLY_CAPTURES = "C:\chemin\vers\dossier"; flutter test test/captures
//
// Les PNG sont écrits dans ce dossier (accueil_clair.png, …).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vally_business/core/format/dates.dart';
import 'package:vally_business/core/router/coquille_onglets.dart';
import 'package:vally_business/features/accueil/presentation/accueil_page.dart';
import 'package:vally_business/features/auth/data/auth_repository.dart';
import 'package:vally_business/features/plus/presentation/plus_page.dart';
import 'package:vally_business/features/stock/presentation/article_form_page.dart';
import 'package:vally_business/features/stock/presentation/reapprovisionnement_page.dart';
import 'package:vally_business/features/stock/presentation/stock_page.dart';
import 'package:vally_business/features/ventes/presentation/commandes_page.dart';
import 'package:vally_business/features/ventes/presentation/ventes_page.dart';
import 'package:vally_business/features/boutique/data/boutique_repository.dart';
import 'package:vally_business/features/clients/data/clients_repository.dart';
import 'package:vally_business/features/clients/domain/client_resume.dart';
import 'package:vally_business/features/depenses/data/depenses_repository.dart';
import 'package:vally_business/features/depenses/domain/mouvement.dart';
import 'package:vally_business/features/depenses/presentation/depenses_page.dart';
import 'package:vally_business/features/stock/data/stock_repository.dart';
import 'package:vally_business/features/stock/domain/article.dart';
import 'package:vally_business/features/tableau_de_bord/data/tableau_de_bord_repository.dart';
import 'package:vally_business/features/tableau_de_bord/domain/indicateurs.dart';
import 'package:vally_business/features/ventes/data/ventes_repository.dart';
import 'package:vally_business/features/ventes/domain/commande.dart';
import 'package:vally_business/theme/app_theme.dart';

import '../stock/donnees.dart';
import '../ventes/donnees_ventes.dart';

final _sortie = Platform.environment['VALLY_CAPTURES'];
final _cle = GlobalKey();

class _FauxAuth implements AuthRepository {
  @override
  User? get utilisateurActuel => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Roboto et icônes Material (fournies avec le SDK Flutter), Space Grotesk (projet).
Future<void> _chargerPolices() async {
  final sdk = Platform.environment['FLUTTER_ROOT'] ?? 'C:/Tools/flutter';
  final dossier = '$sdk/bin/cache/artifacts/material_fonts';
  Future<ByteData> lire(String f) async => ByteData.sublistView(File('$dossier/$f').readAsBytesSync());
  final roboto = FontLoader('Roboto');
  for (final f in ['roboto-light.ttf', 'roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf', 'roboto-black.ttf']) {
    roboto.addFont(lire(f));
  }
  await roboto.load();
  await (FontLoader('MaterialIcons')..addFont(lire('materialicons-regular.otf'))).load();
  await (FontLoader('SpaceGrotesk')..addFont(rootBundle.load('assets/fonts/SpaceGrotesk-Bold.ttf'))).load();
}

String _jour(int decalage) => FormatDate.iso(DateTime.now().add(Duration(days: decalage)));

Commande _vente(String id, int jour, num total,
    {String? client, num? paye, String heure = '10:15', bool annulee = false, List<Map<String, Object>>? articles}) {
  final j = ligneVCommandes(
    id: id,
    articles: articles,
    clientNom: client,
    total: total,
    paye: paye ?? total,
    statutPaiement: (paye ?? total) >= total ? 'soldee' : (paye == 0 ? 'non_payee' : 'partiellement_payee'),
    statutLivraison: annulee ? 'annulee' : 'livree',
    date: _jour(jour),
  )..['created_at'] = '${_jour(jour)}T$heure:00';
  return Commande.fromJson(j);
}

final _commandes = <Commande>[
  // Aujourd'hui
  _vente('v1', 0, 45000, client: 'Maman Rose', heure: '09:40', articles: [
    {'nom': 'Robe pagne fleurie', 'quantite': 1},
    {'nom': 'Chemise wax homme', 'quantite': 2},
  ]),
  _vente('v2', 0, 18000, heure: '11:05', articles: [{'nom': 'Ensemble garçon', 'quantite': 1}]),
  _vente('v3', 0, 32000, client: 'Grâce Mbuyi', paye: 20000, heure: '14:20', articles: [
    {'nom': 'Robe de soirée satin', 'quantite': 1},
    {'nom': 'Pyjama ourson', 'quantite': 1},
    {'nom': 'Chemise lin blanche', 'quantite': 1},
  ]),
  // Les jours d'avant (semaine)
  _vente('v4', -1, 60000, client: 'Papa Jo'),
  _vente('v5', -1, 25000),
  _vente('v5b', -1, 30000, client: 'Sandrine K.', heure: '16:30', annulee: true),
  _vente('v6', -2, 15000),
  _vente('v7', -3, 80000, client: 'Mme Kabila'),
  _vente('v8', -4, 22000),
  _vente('v9', -5, 40000, client: 'Maman Josée', paye: 0),
  _vente('v10', -6, 12000),
  // Commandes
  Commande.fromJson(ligneVCommandes(
      id: 'k1', type: 'commande', statutLivraison: 'en_attente', clientNom: 'Mme Kabila',
      total: 25000, paye: 10000, frais: 3000, date: _jour(-2),
      dateLivraison: _jour(0), modeRemise: 'livraison',
      articles: [{'nom': 'Robe pagne fleurie', 'quantite': 2}])),
  Commande.fromJson(ligneVCommandes(
      id: 'k2', type: 'commande', statutLivraison: 'prete', clientNom: 'Papa Jo',
      total: 38000, paye: 38000, statutPaiement: 'soldee', date: _jour(-4),
      dateLivraison: _jour(-1), modeRemise: 'retrait')),
  Commande.fromJson(ligneVCommandes(
      id: 'k3', type: 'commande', statutLivraison: 'en_attente', clientNom: 'Sandrine K.',
      total: 54000, paye: 20000, date: _jour(-1),
      dateLivraison: _jour(2), modeRemise: 'retrait')),
];

ClientResume _client(String nom, num du, {String? tel}) => ClientResume.fromJson({
      'id': 'cl-$nom', 'nom': nom, 'telephone': tel, 'nb_achats': 4, 'total_achats': 180000,
      'total_du': du, 'nb_impayes': du > 0 ? 1 : 0, 'dernier_achat': _jour(-3),
    });

final _clients = [
  _client('Maman Josée', 40000, tel: '081 234 5678'),
  _client('Grâce Mbuyi', 12000, tel: '099 876 5432'),
  _client('Mme Kabila', 15000),
  _client('Papa Jo', 0),
];

final _articles = <Article>[
  article(nom: 'Robe pagne fleurie', quantiteAchetee: 6, quantiteVendue: 5),
  article(nom: 'Chemise wax homme', categorie: 'Chemise', quantiteAchetee: 4, quantiteVendue: 4),
  article(nom: 'Ensemble garçon', categorie: 'Ensemble', quantiteAchetee: 10, quantiteVendue: 3),
  article(nom: 'Robe de soirée satin', quantiteAchetee: 4, quantiteVendue: 1),
  Article.fromJson(ligneVStock(
      nom: 'Pyjama ourson', categorie: 'Ensemble', taille: '2 ans', couleur: null, quantiteAchetee: 3)
    ..['pour_enfant'] = true),
  article(nom: 'Chemise lin blanche', categorie: 'Chemise', couleur: 'Blanc', quantiteAchetee: 6, quantiteVendue: 2),
  // Rachetée une fois : 10 à 10 000 (8 vendues), puis 6 à 12 000 → coût
  // moyen (2 × 10 000 + 6 × 12 000) ÷ 8 = 11 500 ; 14 vendues en tout.
  Article.fromJson(ligneVStock(
      id: 'robe-rachetee', nom: 'Robe brodée cérémonie', couleur: 'Bordeaux',
      quantiteAchetee: 16, quantiteVendue: 14, prixAchat: 11500)
    ..['nb_achats'] = 2
    ..['total_approvisionne'] = 172000
    ..['prix_vente_habituel'] = 18000
    ..['fournisseur'] = 'Grossiste Kin'),
];

final _achatsRobe = <Achat>[
  Achat.fromJson({
    'id': 'r2', 'date_appro': _jour(-3), 'quantite': 6, 'prix_achat': 12000, 'fournisseur': 'Grossiste Kin',
    'prix_moyen_avant': 10000, 'devise_saisie': null, 'montant_saisi': null, 'taux_change': null,
    'created_at': '${_jour(-3)}T10:00:00Z',
  }),
  Achat.fromJson({
    'id': 'r1', 'date_appro': _jour(-19), 'quantite': 10, 'prix_achat': 10000, 'fournisseur': 'Marché central',
    'prix_moyen_avant': null, 'devise_saisie': null, 'montant_saisi': null, 'taux_change': null,
    'created_at': '${_jour(-19)}T10:00:00Z',
  }),
];

// ─── Mes dépenses ───
/// Un jour du mois en cours (jamais avant le 1er), pour garder la démo dans le mois.
String _jourDuMois(int recul) {
  final n = DateTime.now();
  return FormatDate.iso(DateTime(n.year, n.month, (n.day - recul).clamp(1, 31)));
}

Mouvement _mouvement(String id, String type, num montant, String categorie, String date,
        {String source = 'manuel', String? note, String devise = 'CDF', num? saisi, num? taux}) =>
    Mouvement.fromJson({
      'id': id, 'type': type, 'montant': montant, 'categorie': categorie,
      'date_mouvement': date, 'note': note, 'source': source,
      'devise_saisie': devise, 'montant_saisi': saisi ?? montant, 'taux_change': taux,
      'created_at': '${date}T10:00:00Z',
    });

final _mouvements = <Mouvement>[
  _mouvement('m1', 'sortie', 12000, 'Transport', _jourDuMois(0), note: 'Taxi-moto, marché central'),
  _mouvement('m2', 'sortie', 25000, 'Nourriture', _jourDuMois(1)),
  _mouvement('m3', 'entree', 150000, 'Bénéfice boutique', _jourDuMois(2), source: 'boutique', note: 'Pour le loyer'),
  _mouvement('m4', 'sortie', 80000, 'Loyer', _jourDuMois(2)),
  _mouvement('m5', 'sortie', 35000, 'École', _jourDuMois(5), note: 'Frais scolaires'),
  _mouvement('m6', 'entree', 56000, 'Cadeau', _jourDuMois(6), devise: 'USD', saisi: 20, taux: 2800),
  _mouvement('m7', 'sortie', 9000, 'Factures', _jourDuMois(6), note: 'Électricité'),
];

List<FluxMensuel> _flux() {
  final n = DateTime.now();
  DateTime mois(int recul) => DateTime(n.year, n.month - recul);
  return [
    FluxMensuel(mois: mois(0), entrees: 206000, sorties: 161000, soldeCumule: 98000),
    FluxMensuel(mois: mois(1), entrees: 180000, sorties: 195000, soldeCumule: 53000),
    FluxMensuel(mois: mois(2), entrees: 140000, sorties: 92000, soldeCumule: 68000),
    FluxMensuel(mois: mois(3), entrees: 60000, sorties: 40000, soldeCumule: 20000),
  ];
}

const _indicateurs = IndicateursActuels(
  valeurStockRestant: 180000, piecesEnStock: 18, articlesEpuises: 1,
  beneficeRealise: 390000, beneficeEncaisse: 340000,
  beneficeVerse: 150000, beneficeDisponible: 190000, resteDu: 67000,
);

/// [onglets] : faux pour un écran plein (fiche, formulaire), sans barre du bas.
Future<void> _afficher(WidgetTester tester, Widget page, ThemeData theme,
    {double hauteur = 806, bool onglets = true}) async {
  tester.view.physicalSize = Size(720, hauteur * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(RepaintBoundary(
    key: _cle,
    child: ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FauxAuth()),
        utilisateurIdProvider.overrideWith((ref) => Stream.value('user-1')),
        boutiqueProvider.overrideWith((ref) async => boutiqueTest),
        articlesProvider.overrideWith((ref) async => _articles),
        commandesProvider.overrideWith((ref) async => _commandes),
        clientsResumeProvider.overrideWith((ref) async => _clients),
        mouvementsProvider.overrideWith((ref) async => _mouvements),
        fluxMensuelProvider.overrideWith((ref) async => _flux()),
        indicateursActuelsProvider.overrideWith((ref) async => _indicateurs),
        achatsArticleProvider.overrideWith((ref, id) async => id == 'robe-rachetee' ? _achatsRobe : const []),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('fr', 'FR')],
        locale: const Locale('fr', 'FR'),
        home: Consumer(
          builder: (context, ref, _) => !ref.watch(boutiqueProvider).hasValue
              ? const SizedBox.shrink()
              : onglets
                  ? Scaffold(
                      body: page,
                      bottomNavigationBar: BarreOnglets(index: 0, badges: const {2: 2}, onTap: (_) {}),
                    )
                  : page,
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  // Laisse le temps aux images d'assets d'être décodées.
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
  await tester.pumpAndSettle();
}

Future<void> _capturer(WidgetTester tester, String nom) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_cle));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_sortie/$nom.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('fr');
    // Polices du SDK seulement quand on produit les captures (absentes en CI).
    if (_sortie != null) await _chargerPolices();
  });

  final ignorer = _sortie == null ? 'Définis VALLY_CAPTURES pour produire les captures.' : null;

  for (final (nom, theme) in [('clair', VallyTheme.light), ('sombre', VallyTheme.dark)]) {
    testWidgets('capture accueil ($nom)', skip: ignorer != null, (tester) async {
      await _afficher(tester, const AccueilPage(), theme);
      await _capturer(tester, 'accueil_$nom');
      await _afficher(tester, const AccueilPage(), theme, hauteur: 1500);
      await _capturer(tester, 'accueil_${nom}_page');
    });
  }

  final autres = <String, Widget>{
    'ventes': const VentesPage(),
    'commandes': const CommandesPage(),
    'stock': const StockPage(),
    'plus': const PlusPage(),
  };
  testWidgets('capture depenses_saisie (clair)', skip: ignorer != null, (tester) async {
    await _afficher(tester, const DepensesPage(), VallyTheme.light);
    await tester.tap(find.byTooltip('Noter une dépense ou une entrée'));
    await tester.pumpAndSettle();
    await _capturer(tester, 'depenses_saisie_clair');
  });

  // Articles : nouvel article, fiche d'un article racheté, feuille « Racheter ».
  testWidgets('capture article_nouveau (clair)', skip: ignorer != null, (tester) async {
    await _afficher(tester, const ArticleFormPage(), VallyTheme.light, hauteur: 1900, onglets: false);
    await _capturer(tester, 'article_nouveau_clair');
  });
  for (final (variante, theme) in [('clair', VallyTheme.light), ('sombre', VallyTheme.dark)]) {
    testWidgets('capture article_fiche ($variante)', skip: ignorer != null, (tester) async {
      await _afficher(tester, const ArticleFormPage(articleId: 'robe-rachetee'), theme,
          hauteur: 1900, onglets: false);
      await _capturer(tester, 'article_fiche_$variante');
    });
  }
  testWidgets('capture article_rachat (clair)', skip: ignorer != null, (tester) async {
    await _afficher(tester, const ArticleFormPage(articleId: 'robe-rachetee'), VallyTheme.light,
        onglets: false);
    await tester.tap(find.text('Racheter'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Combien de pièces as-tu rachetées ?'), '10');
    await tester.pumpAndSettle();
    await _capturer(tester, 'article_rachat_clair');
  });

  // Ajouter au stock : le choix du « + », la page « Réapprovisionner », l'alerte doublon.
  testWidgets('capture stock_choix (clair)', skip: ignorer != null, (tester) async {
    await _afficher(tester, const StockPage(), VallyTheme.light);
    await tester.tap(find.byTooltip('Ajouter au stock'));
    await tester.pumpAndSettle();
    await _capturer(tester, 'stock_choix_clair');
  });
  for (final (variante, theme) in [('clair', VallyTheme.light), ('sombre', VallyTheme.dark)]) {
    testWidgets('capture reappro ($variante)', skip: ignorer != null, (tester) async {
      await _afficher(tester, const ReapprovisionnementPage(), theme, hauteur: 1500, onglets: false);
      await _capturer(tester, 'reappro_$variante');
    });
  }
  testWidgets('capture article_doublon (clair)', skip: ignorer != null, (tester) async {
    await _afficher(tester, const ArticleFormPage(nomPropose: 'Robe pagne fleurie'), VallyTheme.light,
        onglets: false);
    await _capturer(tester, 'article_doublon_clair');
  });

  // Mes dépenses : page entière (longue), en clair et en sombre.
  for (final (variante, theme) in [('clair', VallyTheme.light), ('sombre', VallyTheme.dark)]) {
    testWidgets('capture depenses ($variante)', skip: ignorer != null, (tester) async {
      await _afficher(tester, const DepensesPage(), theme, hauteur: 1700);
      await _capturer(tester, 'depenses_$variante');
    });
  }

  for (final MapEntry(key: nom, value: page) in autres.entries) {
    for (final (variante, theme) in [('clair', VallyTheme.light), ('sombre', VallyTheme.dark)]) {
      testWidgets('capture $nom ($variante)', skip: ignorer != null, (tester) async {
        await _afficher(tester, page, theme);
        await _capturer(tester, '${nom}_$variante');
      });
    }
  }
}

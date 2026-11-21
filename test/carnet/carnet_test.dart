import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vally_business/core/format/dates.dart';
import 'package:vally_business/core/format/montant.dart';
import 'package:vally_business/core/widgets/carnet.dart';
import 'package:vally_business/core/widgets/elements.dart';
import 'package:vally_business/features/auth/data/auth_repository.dart';
import 'package:vally_business/features/boutique/data/boutique_repository.dart';
import 'package:vally_business/features/stock/domain/article.dart';
import 'package:vally_business/features/ventes/data/ventes_repository.dart';
import 'package:vally_business/features/ventes/domain/commande.dart';
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

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  group('Titre des jours (haut de page du cahier)', () {
    final a = DateTime(2026, 11, 21, 10);

    test('aujourd’hui, hier, demain', () {
      expect(FormatDate.titreJour(DateTime(2026, 11, 21, 23), aujourdhui: a), 'Aujourd’hui');
      expect(FormatDate.titreJour(DateTime(2026, 11, 20), aujourdhui: a), 'Hier');
      expect(FormatDate.titreJour(DateTime(2026, 11, 22), aujourdhui: a), 'Demain');
    });

    test('sinon le jour en toutes lettres, « 1er » pour le premier du mois', () {
      expect(FormatDate.titreJour(DateTime(2026, 11, 19), aujourdhui: a), 'Jeudi 19 novembre');
      expect(FormatDate.titreJour(DateTime(2026, 11, 1), aujourdhui: a), 'Dimanche 1er novembre');
      expect(FormatDate.titreJour(DateTime(2025, 12, 24), aujourdhui: a), 'Mercredi 24 décembre 2025');
      expect(FormatDate.jourLong(a, aujourdhui: a), 'Samedi 21 novembre');
    });
  });

  group('Phrase du stock', () {
    ResumeStock resume(int pieces, num valeur, num investi) => ResumeStock(
          totalApprovisionne: investi.toDouble(),
          valeurStockRestant: valeur.toDouble(),
          piecesEnStock: pieces,
          nbArticles: 3,
          nbEpuises: 0,
          nbStockFaible: 0,
        );
    final f = FormatMontant.formater;

    test('pluriel, singulier, rien', () {
      expect(phraseStock(resume(8, 80000, 200000), Devise.cdf),
          '8 pièces en boutique, qui t’ont coûté ${f(80000, Devise.cdf)}. '
          'Depuis le début, tu as investi ${f(200000, Devise.cdf)}.');
      expect(phraseStock(resume(1, 10000, 50000), Devise.cdf),
          startsWith('1 pièce en boutique, qui t’a coûté '));
      expect(phraseStock(resume(0, 0, 50000), Devise.cdf),
          startsWith('Plus aucune pièce en boutique. Depuis le début'));
    });

    test('jamais de point d’exclamation (charte)', () {
      for (final n in [0, 1, 5]) {
        expect(phraseStock(resume(n, n * 1000, 9000), Devise.cdf), isNot(contains('!')));
      }
    });
  });

  testWidgets('phrase de résumé : nombres et montants entiers en gras', (tester) async {
    final montant = FormatMontant.formater(80000, Devise.cdf);
    await tester.pumpWidget(MaterialApp(
      theme: VallyTheme.light,
      home: Scaffold(body: PhraseAvecChiffres('8 pièces, qui t’ont coûté $montant.')),
    ));
    final texte = tester.widget<Text>(find.byType(Text));
    final gras = (texte.textSpan! as TextSpan)
        .children!
        .cast<TextSpan>()
        .where((s) => s.style?.fontWeight == FontWeight.w700)
        .map((s) => s.text)
        .toList();
    expect(gras, ['8', montant]);
  });

  testWidgets('Ventes : total du jour en bas de la carte, sans les ventes annulées',
      (tester) async {
    final jour = FormatDate.iso(DateTime.now());
    final ventes = [
      Commande.fromJson(ligneVCommandes(
          id: 'v1', date: jour, total: 30000, paye: 30000, statutPaiement: 'soldee',
          articles: [
            {'nom': 'Robe pagne fleurie', 'quantite': 1},
            {'nom': 'Chemise wax', 'quantite': 2},
          ])),
      Commande.fromJson(ligneVCommandes(id: 'v2', date: jour, total: 20000, paye: 5000)),
      Commande.fromJson(ligneVCommandes(
          id: 'v3', date: jour, total: 99000, statutLivraison: 'annulee')),
    ];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FauxAuth()),
        utilisateurIdProvider.overrideWith((ref) => Stream.value('user-1')),
        boutiqueProvider.overrideWith((ref) async => boutiqueTest),
        commandesProvider.overrideWith((ref) async => ventes),
      ],
      child: MaterialApp(
        theme: VallyTheme.light,
        home: Consumer(
          builder: (context, ref, _) =>
              ref.watch(boutiqueProvider).hasValue ? const VentesPage() : const SizedBox.shrink(),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Aujourd’hui'), findsOneWidget);
    final e = String.fromCharCode(0xA0); // espace insécable
    // Ce qui a été vendu, quand la base le fournit…
    expect(find.text('Robe pagne fleurie, 2$e×${e}Chemise wax'), findsOneWidget);
    // … sinon le nombre de pièces (« 2 » et « pièces » jamais séparés).
    expect(find.text('2${e}pièces'), findsNWidgets(2));
    expect(find.text('Total · 2 ventes'), findsOneWidget);
    expect(find.text(FormatMontant.formater(50000, Devise.cdf)), findsOneWidget);

    // Ventes non payées : le bas de carte devient ce qu'il reste à encaisser.
    await tester.tap(find.widgetWithText(FiltrePastille, 'Non payées'));
    await tester.pumpAndSettle();
    expect(find.text('Reste à encaisser'), findsOneWidget);
    expect(find.text(FormatMontant.formater(15000, Devise.cdf, sens: SensMontant.negatif)),
        findsOneWidget);
  });
}

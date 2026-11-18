import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vally_business/features/factures/data/facture_pdf.dart';
import 'package:vally_business/features/factures/domain/facture.dart';
import 'package:vally_business/features/ventes/domain/commande.dart';

import '../stock/donnees.dart';
import '../ventes/donnees_ventes.dart';

Commande _c(Map<String, dynamic> j) => Commande.fromJson(j..['numero'] = '2026-0042');

void main() {
  setUpAll(() => initializeDateFormatting('fr'));
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Message de remerciement', () {
    test('vente soldée', () {
      final m = messageRemerciement(
          _c(ligneVCommandes(statutPaiement: 'soldee', paye: 22000)),
          boutique: 'Vally', devise: boutiqueTest.devise);
      expect(m, contains('Bonjour Maman Rose, merci pour ton achat chez Vally.'));
      expect(m, contains('facture n° 2026-0042'));
      expect(m, contains('Tout est réglé, merci.'));
      expect(m, isNot(contains('!')));
    });

    test('avance : payé et reste', () {
      final m = messageRemerciement(_c(ligneVCommandes()), boutique: 'Vally', devise: boutiqueTest.devise);
      expect(m, contains('Tu as déjà payé 14 000 CDF, il reste 8 000 CDF à régler.'));
    });

    test('commande à livrer : date et mode', () {
      final m = messageRemerciement(
          _c(ligneVCommandes(
              type: 'commande', statutLivraison: 'en_attente', statutPaiement: 'non_payee', paye: 0,
              dateLivraison: '2026-12-24', modeRemise: 'livraison')),
          boutique: 'Vally', devise: boutiqueTest.devise);
      expect(m, contains('merci pour ta commande'));
      expect(m, contains('Montant à régler : 22 000 CDF.'));
      expect(m, contains('Livraison prévue le 24 déc. 2026.'));
    });

    test('client de passage : simple « Bonjour »', () {
      final m = messageRemerciement(_c(ligneVCommandes(clientNom: null)),
          boutique: 'Vally', devise: boutiqueTest.devise);
      expect(m, startsWith('Bonjour, merci'));
    });
  });

  test('texte PDF : espaces fines, signe moins, apostrophes', () {
    expect(pourPdf('− 8 000 CDF · l’été 😀'), "- 8 000 CDF · l'été ");
    expect(nomFichierFacture(_c(ligneVCommandes())), 'Facture-2026-0042.pdf');
  });

  test('génère une facture PDF valide', () async {
    final commande = _c(ligneVCommandes(
      type: 'commande', statutLivraison: 'prete', total: 25000, frais: 3000, paye: 14000,
      dateLivraison: '2026-11-22', modeRemise: 'livraison',
    ));
    final detail = CommandeDetail(
      commande: commande,
      lignes: [
        LigneCommande.fromJson({
          'id': 'l1', 'article_id': 'a1', 'quantite': 2, 'prix_vendu': 11000,
          'prix_achat_snapshot': 8000, 'prix_habituel_snapshot': 12000,
          'articles': {'nom': 'Ensemble garçon brodé', 'categorie': 'Ensemble', 'taille': '4 ans', 'couleur': 'Bleu'},
        }),
      ],
      paiements: [
        Paiement.fromJson({
          'id': 'p1', 'montant': 14000, 'date_paiement': '2026-11-19', 'mode': 'mobile_money',
          'devise_saisie': 'USD', 'montant_saisi': 5, 'taux_change': 2800,
        }),
      ],
    );
    final octets = await genererFacturePdf(detail: detail, boutique: boutiqueTest);
    expect(String.fromCharCodes(octets.take(5)), '%PDF-');
    expect(octets.length, greaterThan(2000));
    // Copie pour relecture visuelle si VALLY_PDF_SORTIE est défini.
    final sortie = Platform.environment['VALLY_PDF_SORTIE'];
    if (sortie != null) File(sortie).writeAsBytesSync(octets);
  });
}

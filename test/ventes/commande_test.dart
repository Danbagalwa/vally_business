import 'package:flutter_test/flutter_test.dart';
import 'package:vally_business/core/format/montant.dart';
import 'package:vally_business/features/ventes/domain/commande.dart';
import 'package:vally_business/features/ventes/domain/panier.dart';

import '../stock/donnees.dart';

Map<String, dynamic> ligneVCommandes({
  String id = 'c1',
  String? clientNom = 'Maman Rose',
  String statutLivraison = 'en_attente',
  String statutPaiement = 'partiellement_payee',
  num total = 22000,
  num paye = 14000,
}) =>
    {
      'id': id,
      'client_id': clientNom == null ? null : 'cl1',
      'client_nom': clientNom,
      'client_telephone': '+243 99 000 0000',
      'date_commande': '2026-11-18',
      'statut_livraison': statutLivraison,
      'note': null,
      'nb_pieces': 2,
      'total': total,
      'cout': 16000,
      'benefice': total - 16000,
      'gain_au_dessus': 0,
      'cout_remises': 2000,
      'total_paye': paye,
      'reste_a_payer': statutLivraison == 'annulee' ? 0 : total - paye,
      'statut_paiement': statutPaiement,
      'created_at': '2026-11-18T09:00:00Z',
    };

void main() {
  test('Commande.fromJson (ligne de v_commandes)', () {
    final c = Commande.fromJson(ligneVCommandes());
    expect(c.nomAffiche, 'Maman Rose');
    expect(c.resteAPayer, 8000);
    expect(c.statutPaiement, StatutPaiement.partiellementPayee);
    expect(c.ecartPrixHabituel, -2000);
    expect(c.aEncaisser, isTrue);
    expect(Commande.fromJson(ligneVCommandes(clientNom: null)).nomAffiche,
        'Client de passage');
  });

  test('Paiement converti : garde le montant saisi et le taux', () {
    final p = Paiement.fromJson({
      'id': 'p1',
      'montant': 14000,
      'date_paiement': '2026-11-18',
      'mode': 'mobile_money',
      'devise_saisie': 'USD',
      'montant_saisi': 5,
      'taux_change': 2800,
    });
    expect(p.converti, isTrue);
    expect(p.deviseSaisie, Devise.usd);
    expect(p.mode.libelle, 'Mobile money');
  });

  group('filtrerCommandes', () {
    final commandes = [
      Commande.fromJson(ligneVCommandes(id: 'a')),
      Commande.fromJson(ligneVCommandes(
          id: 'b', clientNom: 'Papa Jo', statutPaiement: 'soldee',
          paye: 22000, statutLivraison: 'livree')),
      Commande.fromJson(ligneVCommandes(
          id: 'c', statutLivraison: 'annulee', statutPaiement: 'non_payee', paye: 0)),
    ];

    test('par statut', () {
      ids(FiltreVentes f) =>
          filtrerCommandes(commandes, filtre: f).map((c) => c.id).toList();
      expect(ids(FiltreVentes.aEncaisser), ['a']);
      expect(ids(FiltreVentes.soldees), ['b']);
      expect(ids(FiltreVentes.aLivrer), ['a']);
      expect(ids(FiltreVentes.annulees), ['c']);
      expect(ids(FiltreVentes.toutes).length, 3);
    });

    test('par client ou téléphone', () {
      expect(filtrerCommandes(commandes, recherche: 'jo').single.id, 'b');
      expect(filtrerCommandes(commandes, recherche: '99000').length, 3);
    });
  });

  test('Panier : total, bénéfice prévu, remise et dépassement de stock', () {
    final robe = article(quantiteAchetee: 5, quantiteVendue: 3, prixAchat: 10000);
    // Prix habituel 15 000 : vendu 13 000 → remise de 2 000 par pièce.
    final l = LignePanier(article: robe, quantite: 2, prixVendu: 13000);
    final totaux = TotauxPanier.depuis([l]);
    expect(totaux.total, 26000);
    expect(totaux.benefice, 6000);
    expect(totaux.ecart, -4000);
    expect(l.depasseStock, isFalse);
    expect(LignePanier(article: robe, quantite: 3, prixVendu: 1).depasseStock, isTrue);
    expect(l.toJson(), {'article_id': robe.id, 'quantite': 2, 'prix_vendu': 13000.0});
  });
}

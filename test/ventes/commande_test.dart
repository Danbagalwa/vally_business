import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vally_business/core/format/dates.dart';
import 'package:vally_business/core/format/montant.dart';
import 'package:vally_business/features/accueil/domain/resume_jour.dart';
import 'package:vally_business/features/clients/domain/client_resume.dart';
import 'package:vally_business/features/ventes/domain/commande.dart';
import 'package:vally_business/features/ventes/domain/panier.dart';

import '../stock/donnees.dart';
import 'donnees_ventes.dart';

final _aujourdhui = DateTime(2026, 11, 18, 15, 30);

Commande _c(Map<String, dynamic> j) => Commande.fromJson(j);

Commande _commande(String id, String livraison, {String statut = 'en_attente'}) => _c(ligneVCommandes(
      id: id,
      type: 'commande',
      statutLivraison: statut,
      dateLivraison: livraison,
      modeRemise: 'retrait',
    ));

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  test('Commande.fromJson : vente, frais de livraison, client de passage', () {
    final c = _c(ligneVCommandes(
        type: 'commande', statutLivraison: 'prete', total: 25000, frais: 3000,
        dateLivraison: '2026-11-20', modeRemise: 'livraison'));
    expect(c.estCommande, isTrue);
    expect(c.statutLivraison, StatutLivraison.prete);
    expect(c.totalArticles, 22000);
    expect(c.fraisLivraison, 3000);
    expect(c.modeRemise, ModeRemise.livraison);
    expect(c.aLivrer, isTrue);
    expect(_c(ligneVCommandes(clientNom: null)).nomAffiche, 'Client de passage');
    expect(_c(ligneVCommandes()).estCommande, isFalse);
  });

  test('Paiement converti : garde le montant saisi et le taux', () {
    final p = Paiement.fromJson({
      'id': 'p1', 'montant': 14000, 'date_paiement': '2026-11-18', 'mode': 'mobile_money',
      'devise_saisie': 'USD', 'montant_saisi': 5, 'taux_change': 2800,
    });
    expect(p.converti, isTrue);
    expect(p.deviseSaisie, Devise.usd);
    expect(p.mode.libelle, 'Mobile money');
  });

  group('Ventes et commandes séparées', () {
    final toutes = [
      _c(ligneVCommandes(id: 'v1')),
      _c(ligneVCommandes(id: 'v2', statutPaiement: 'soldee', paye: 22000)),
      _c(ligneVCommandes(id: 'v3', statutLivraison: 'annulee', statutPaiement: 'non_payee', paye: 0)),
      _commande('k-auj', '2026-11-18'),
      _commande('k-retard', '2026-11-15'),
      _commande('k-demain', '2026-11-19', statut: 'prete'),
      _commande('k-plus-tard', '2026-11-25'),
      _commande('k-livree', '2026-11-10', statut: 'livree'),
      _commande('k-annulee', '2026-11-18', statut: 'annulee'),
    ];
    List<String> ids(List<Commande> l) => l.map((c) => c.id).toList();

    test('l’onglet Ventes ne montre que les ventes au comptoir', () {
      expect(ids(filtrerVentes(toutes)), ['v1', 'v2', 'v3']);
      expect(ids(filtrerVentes(toutes, filtre: FiltreVentes.nonPayees)), ['v1']);
      expect(ids(filtrerVentes(toutes, filtre: FiltreVentes.annulees)), ['v3']);
    });

    test('commandes par date de livraison', () {
      List<String> f(FiltreCommandes filtre) =>
          ids(filtrerCommandes(toutes, aujourdhui: _aujourdhui, filtre: filtre));
      expect(f(FiltreCommandes.aujourdhui), ['k-auj']);
      expect(f(FiltreCommandes.enRetard), ['k-retard']);
      expect(f(FiltreCommandes.aVenir), ['k-demain', 'k-plus-tard']);
      expect(f(FiltreCommandes.livrees), ['k-livree']);
      expect(f(FiltreCommandes.annulees), ['k-annulee']);
    });

    test('commandes d’un jour choisi (annulées exclues)', () {
      expect(
          ids(filtrerCommandes(toutes, aujourdhui: _aujourdhui, jour: DateTime(2026, 11, 18))),
          ['k-auj']);
    });

    test('compteurs et retard', () {
      final n = compterCommandes(toutes, _aujourdhui);
      expect(n[FiltreCommandes.aujourdhui], 1);
      expect(n[FiltreCommandes.enRetard], 1);
      expect(n[FiltreCommandes.aVenir], 2);
      expect(toutes.firstWhere((c) => c.id == 'k-retard').estEnRetard(_aujourdhui), isTrue);
      expect(toutes.firstWhere((c) => c.id == 'k-livree').estEnRetard(_aujourdhui), isFalse);
    });

    test('regroupement par jour', () {
      final g = grouperParJour(
          filtrerCommandes(toutes, aujourdhui: _aujourdhui, filtre: FiltreCommandes.aVenir),
          (c) => c.dateLivraison!);
      expect(g.keys, [DateTime(2026, 11, 19), DateTime(2026, 11, 25)]);
    });

    test('résumé du jour : annulées exclues, frais hors chiffre', () {
      final r = ResumePeriode.du(toutes, (d) => d == DateTime(2026, 11, 18));
      expect(r.nbVentes, 7);
      expect(r.totalVendu, 7 * 22000);
    });
  });

  group('Clients et dettes', () {
    ClientResume client(String nom, num du, {String? tel}) => ClientResume.fromJson({
          'id': nom, 'nom': nom, 'telephone': tel, 'nb_achats': 2, 'total_achats': 50000,
          'total_du': du, 'nb_impayes': du > 0 ? 1 : 0, 'dernier_achat': '2026-11-10',
        });
    final clients = [
      client('Maman Rose', 8000, tel: '081 234 5678'),
      client('Papa Jo', 0),
      client('Mme Kabila', 25000),
    ];

    test('« Me doivent » : seulement les dettes, la plus grosse d’abord', () {
      expect(filtrerClients(clients, filtre: FiltreClients.meDoivent).map((c) => c.nom),
          ['Mme Kabila', 'Maman Rose']);
    });

    test('recherche par nom ou par chiffres du téléphone', () {
      expect(filtrerClients(clients, recherche: 'jo').single.nom, 'Papa Jo');
      expect(filtrerClients(clients, recherche: '2345').single.nom, 'Maman Rose');
      expect(clients.first.initiales, 'MR');
    });

    test('numéro WhatsApp : indicatif 243 ajouté', () {
      expect(numeroWhatsApp('081 234 5678'), '243812345678');
      expect(numeroWhatsApp('+243 81 234 5678'), '243812345678');
      expect(numeroWhatsApp('00243812345678'), '243812345678');
      expect(numeroWhatsApp(null), isNull);
    });
  });

  test('dates relatives', () {
    final a = DateTime(2026, 11, 18);
    expect(FormatDate.relatif(DateTime(2026, 11, 18, 22), aujourdhui: a), 'Aujourd’hui');
    expect(FormatDate.relatif(DateTime(2026, 11, 19), aujourdhui: a), 'Demain');
    expect(FormatDate.relatif(DateTime(2026, 11, 17), aujourdhui: a), 'Hier');
    expect(FormatDate.relatif(DateTime(2026, 11, 24), aujourdhui: a), 'mar. 24 nov.');
    expect(FormatDate.relatif(DateTime(2027, 1, 4), aujourdhui: a), 'lun. 4 janv. 2027');
  });

  test('Panier : total, bénéfice prévu, remise et dépassement de stock', () {
    final robe = article(quantiteAchetee: 5, quantiteVendue: 3, prixAchat: 10000);
    final l = LignePanier(article: robe, quantite: 2, prixVendu: 13000);
    final totaux = TotauxPanier.depuis([l]);
    expect(totaux.total, 26000);
    expect(totaux.benefice, 6000);
    expect(totaux.ecart, -4000);
    expect(l.depasseStock, isFalse);
    expect(LignePanier(article: robe, quantite: 3, prixVendu: 1).depasseStock, isTrue);
  });
}

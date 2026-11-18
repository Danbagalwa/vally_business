import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vally_business/features/stock/domain/article.dart';
import 'package:vally_business/features/tableau_de_bord/domain/indicateurs.dart';
import 'package:vally_business/features/tableau_de_bord/domain/periode.dart';
import 'package:vally_business/features/ventes/domain/commande.dart';

import '../stock/donnees.dart';
import '../ventes/commande_test.dart' show ligneVCommandes;

final _aujourdhui = DateTime(2026, 11, 18);

Commande _commande(String date, num total, {bool annulee = false}) {
  final j = ligneVCommandes(
    total: total,
    paye: 0,
    statutPaiement: 'non_payee',
    statutLivraison: annulee ? 'annulee' : 'livree',
  );
  j['date_commande'] = date;
  j['benefice'] = total / 2;
  return Commande.fromJson(j);
}

Article _article({required String dateAppro, String? derniereVente, int vendu = 0}) {
  final j = ligneVStock(quantiteAchetee: 5, quantiteVendue: vendu);
  j['date_appro'] = dateAppro;
  j['derniere_vente'] = derniereVente;
  return Article.fromJson(j);
}

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  group('Periode', () {
    test('ce mois, mois dernier, cette année (bornes incluses)', () {
      final mois = Periode.de(TypePeriode.ceMois, aujourdhui: _aujourdhui);
      expect(mois.debut, DateTime(2026, 11, 1));
      expect(mois.fin, DateTime(2026, 11, 30));
      expect(mois.libelle, 'novembre 2026');

      final dernier = Periode.de(TypePeriode.moisDernier, aujourdhui: DateTime(2026, 1, 10));
      expect(dernier.debut, DateTime(2025, 12, 1));
      expect(dernier.fin, DateTime(2025, 12, 31));

      final annee = Periode.de(TypePeriode.cetteAnnee, aujourdhui: _aujourdhui);
      expect((annee.debut, annee.fin, annee.libelle),
          (DateTime(2026), DateTime(2026, 12, 31), '2026'));
    });

    test('personnalisée : heures ignorées', () {
      final p = Periode.personnalisee(
          DateTime(2026, 11, 3, 15, 30), DateTime(2026, 11, 18, 9));
      expect(p.debut, DateTime(2026, 11, 3));
      expect(p.fin, DateTime(2026, 11, 18));
      expect(p.libelle, '3 nov. 2026 – 18 nov. 2026');
    });
  });

  test('parMois : 6 mois, mois vides à 0, annulées exclues', () {
    final points = parMois([
      _commande('2026-11-02', 20000),
      _commande('2026-11-15', 10000),
      _commande('2026-11-16', 99000, annulee: true),
      _commande('2026-08-01', 8000),
      _commande('2026-01-05', 50000), // hors des 6 derniers mois
    ], aujourdhui: _aujourdhui);
    expect(points.length, 6);
    expect(points.first.mois, DateTime(2026, 6));
    expect(points.last.mois, DateTime(2026, 11));
    expect(points.last.chiffreAffaires, 30000);
    expect(points.last.benefice, 15000);
    expect(points[2].chiffreAffaires, 8000); // août
    expect(points[1].chiffreAffaires, 0); // juillet
  });

  test('articlesQuiNePartentPas : 30 jours sans vente, plus anciens d’abord', () {
    final jamaisVendu = _article(dateAppro: '2026-09-01');
    final venduRecemment = _article(dateAppro: '2026-08-01', derniereVente: '2026-11-10', vendu: 1);
    final venteAncienne = _article(dateAppro: '2026-07-01', derniereVente: '2026-10-01', vendu: 1);
    final neuf = _article(dateAppro: '2026-11-15');
    final epuise = _article(dateAppro: '2026-01-01', vendu: 5);

    final lents = articlesQuiNePartentPas(
        [jamaisVendu, venduRecemment, venteAncienne, neuf, epuise],
        aujourdhui: _aujourdhui);
    expect(lents, [jamaisVendu, venteAncienne]);
    expect(joursSansVente(jamaisVendu, _aujourdhui), 78);
  });

  test('IndicateursActuels.fromJson (ligne de v_dashboard)', () {
    final a = IndicateursActuels.fromJson({
      'valeur_stock_restant': 20000,
      'pieces_en_stock': 2,
      'articles_epuises': 1,
      'benefice_realise': 26000,
      'benefice_verse': 14000,
      'benefice_disponible': 12000,
      'reste_du': 0,
    });
    expect(a.beneficeDisponible, 12000);
    expect(a.piecesEnStock, 2);
  });
}

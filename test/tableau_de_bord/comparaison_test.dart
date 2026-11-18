import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vally_business/core/widgets/delta_texte.dart';
import 'package:vally_business/features/tableau_de_bord/domain/indicateurs.dart';
import 'package:vally_business/features/tableau_de_bord/domain/periode.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr'));
  final aujourdhui = DateTime(2026, 11, 19);

  group('Période de comparaison', () {
    test('ce mois → les mêmes jours du mois dernier', () {
      final p = Periode.de(TypePeriode.ceMois, aujourdhui: aujourdhui).precedente(aujourdhui: aujourdhui);
      expect((p.debut, p.fin), (DateTime(2026, 10, 1), DateTime(2026, 10, 19)));
    });

    test('ce mois le 31 → plafonné au dernier jour du mois précédent', () {
      final a = DateTime(2026, 12, 31);
      final p = Periode.de(TypePeriode.ceMois, aujourdhui: a).precedente(aujourdhui: a);
      expect((p.debut, p.fin), (DateTime(2026, 11, 1), DateTime(2026, 11, 30)));
    });

    test('mois dernier → le mois d’avant, en entier', () {
      final p = Periode.de(TypePeriode.moisDernier, aujourdhui: aujourdhui).precedente(aujourdhui: aujourdhui);
      expect((p.debut, p.fin), (DateTime(2026, 9, 1), DateTime(2026, 9, 30)));
    });

    test('cette année → l’an dernier jusqu’à la même date', () {
      final p = Periode.de(TypePeriode.cetteAnnee, aujourdhui: aujourdhui).precedente(aujourdhui: aujourdhui);
      expect((p.debut, p.fin), (DateTime(2025, 1, 1), DateTime(2025, 11, 19)));
    });

    test('personnalisée → autant de jours, juste avant', () {
      final p = Periode.personnalisee(DateTime(2026, 11, 10), DateTime(2026, 11, 16)).precedente();
      expect((p.debut, p.fin), (DateTime(2026, 11, 3), DateTime(2026, 11, 9)));
    });
  });

  test('variation : en % ; impossible si la période précédente vaut 0', () {
    expect(variation(120, 100), closeTo(20, 1e-9));
    expect(variation(80, 100), closeTo(-20, 1e-9));
    expect(variation(-50, -100), closeTo(50, 1e-9));
    expect(variation(10, 0), isNull);
  });

  test('affichage : virgule, signe moins typographique, entier dès 10 %', () {
    expect(DeltaTexte.formater(4.26), '+4,3 %');
    expect(DeltaTexte.formater(-12.4), '−12 %');
  });

  test('panier moyen et marge', () {
    const i = IndicateursPeriode(
      totalApprovisionne: 0, chiffreAffaires: 100000, coutVentes: 60000, benefice: 40000,
      totalEncaisse: 0, resteDu: 0, gainAuDessus: 0, coutRemises: 0, nbCommandes: 4, piecesVendues: 6,
    );
    expect(i.panierMoyen, 25000);
    expect(i.margePourcent, 40);
  });

  test('par catégorie : regroupe, trie et donne la part', () {
    ArticleVendu a(String cat, num ca, int q) => ArticleVendu.fromJson({
          'article_id': '$cat$ca', 'nom': 'x', 'categorie': cat, 'taille': 'M',
          'quantite': q, 'chiffre_affaires': ca, 'benefice': 0,
        });
    final r = parCategorie([a('Robe', 30000, 2), a('Chemise', 50000, 3), a('Robe', 20000, 1)]);
    expect(r.map((c) => c.categorie), ['Robe', 'Chemise']);
    expect(r.first.chiffreAffaires, 50000);
    expect(r.first.quantite, 3);
    expect(r.first.part, 0.5);
  });
}

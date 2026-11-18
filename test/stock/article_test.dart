import 'package:flutter_test/flutter_test.dart';
import 'package:vally_business/features/stock/domain/article.dart';

import 'donnees.dart';

void main() {
  group('Article.fromJson (ligne de v_stock)', () {
    test('lit les nombres (int ou décimaux) et les dates', () {
      final a = Article.fromJson(ligneVStock(
        nom: 'Robe pagne fleurie',
        quantiteAchetee: 5,
        quantiteVendue: 3,
        prixAchat: 10000,
        prixVenteHabituel: 15000.5,
      ));
      expect(a.quantiteRestante, 2);
      expect(a.prixVenteHabituel, 15000.5);
      expect(a.dateAppro, DateTime(2026, 11, 16));
      expect(a.description, 'Robe · M · Rouge');
      expect(a.margeUnitaire, 5000.5);
    });

    test('stock faible et épuisé', () {
      expect(article(quantiteAchetee: 5, quantiteVendue: 0).stockFaible, isFalse);
      expect(article(quantiteAchetee: 5, quantiteVendue: 3).stockFaible, isTrue);
      expect(article(quantiteAchetee: 5, quantiteVendue: 5).epuise, isTrue);
      expect(article(quantiteAchetee: 5, quantiteVendue: 5).stockFaible, isFalse);
    });
  });

  test('ArticleSaisie.toJson : champs vides en null, date ISO', () {
    final json = ArticleSaisie(
      nom: '  Jupe  ',
      categorie: 'Jupe',
      taille: 'S',
      couleur: '  ',
      quantiteAchetee: 2,
      prixAchat: 8000,
      prixVenteHabituel: 12000,
      fournisseur: '',
      dateAppro: DateTime(2026, 3, 5),
    ).toJson();
    expect(json['nom'], 'Jupe');
    expect(json['couleur'], isNull);
    expect(json['fournisseur'], isNull);
    expect(json['date_appro'], '2026-03-05');
  });

  test('ResumeStock additionne investi, valeur restante et alertes', () {
    final r = ResumeStock.depuis([
      article(quantiteAchetee: 5, quantiteVendue: 3, prixAchat: 10000),
      article(quantiteAchetee: 2, quantiteVendue: 2, prixAchat: 5000),
    ]);
    expect(r.totalApprovisionne, 60000);
    expect(r.valeurStockRestant, 20000);
    expect(r.piecesEnStock, 2);
    expect(r.nbEpuises, 1);
    expect(r.nbStockFaible, 1);
  });

  group('filtrerArticles', () {
    final liste = [
      article(nom: 'Robe pagne fleurie', categorie: 'Robe'),
      article(nom: 'Chemise wax', categorie: 'Chemise', couleur: 'Bleu'),
      article(nom: 'Robe de soirée', categorie: 'Robe', couleur: 'Noir'),
    ];

    test('recherche sans tenir compte des accents ni de la casse', () {
      expect(filtrerArticles(liste, recherche: 'SOIREE').map((a) => a.nom),
          ['Robe de soirée']);
    });

    test('plusieurs mots : tous doivent correspondre', () {
      expect(filtrerArticles(liste, recherche: 'robe noir').length, 1);
    });

    test('filtre par catégorie', () {
      expect(filtrerArticles(liste, categorie: 'Robe').length, 2);
      expect(categoriesDe(liste), ['Chemise', 'Robe']);
    });
  });
}

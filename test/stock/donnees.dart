import 'package:vally_business/core/format/montant.dart';
import 'package:vally_business/features/boutique/domain/boutique.dart';
import 'package:vally_business/features/stock/domain/article.dart';

var _compteur = 0;

/// Ligne JSON telle que renvoyée par la vue v_stock.
Map<String, dynamic> ligneVStock({
  String? id,
  String nom = 'Robe pagne fleurie',
  String categorie = 'Robe',
  String taille = 'M',
  String? couleur = 'Rouge',
  int quantiteAchetee = 5,
  int quantiteVendue = 0,
  num prixAchat = 10000,
  num prixVenteHabituel = 15000,
}) =>
    {
      'id': id ?? 'article-${_compteur++}',
      'nom': nom,
      'categorie': categorie,
      'taille': taille,
      'couleur': couleur,
      'quantite_achetee': quantiteAchetee,
      'prix_achat': prixAchat,
      'prix_vente_habituel': prixVenteHabituel,
      'fournisseur': null,
      'date_appro': '2026-11-16',
      'photo_url': null,
      'quantite_vendue': quantiteVendue,
      'quantite_restante': quantiteAchetee - quantiteVendue,
      'total_approvisionne': quantiteAchetee * prixAchat,
      'valeur_stock_restant': (quantiteAchetee - quantiteVendue) * prixAchat,
      'derniere_vente': null,
    };

Article article({
  String nom = 'Robe pagne fleurie',
  String categorie = 'Robe',
  String? couleur,
  int quantiteAchetee = 5,
  int quantiteVendue = 0,
  num prixAchat = 10000,
}) =>
    Article.fromJson(ligneVStock(
      nom: nom,
      categorie: categorie,
      couleur: couleur,
      quantiteAchetee: quantiteAchetee,
      quantiteVendue: quantiteVendue,
      prixAchat: prixAchat,
    ));

final boutiqueTest = Boutique(
  id: 'boutique-1',
  nom: 'Vally',
  devise: Devise.cdf,
  tauxUsdCdf: 2800,
  tauxMajLe: DateTime(2026, 11, 16),
);

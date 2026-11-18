import '../../stock/domain/article.dart';

/// Ligne en cours de saisie dans une nouvelle vente.
/// [prixVendu] est en devise de référence (null si le champ est invalide).
class LignePanier {
  const LignePanier({
    required this.article,
    required this.quantite,
    required this.prixVendu,
  });

  final Article article;
  final int quantite;
  final double? prixVendu;

  double get total => quantite * (prixVendu ?? 0);
  double get cout => quantite * article.prixAchat;

  /// (prix vendu − prix habituel) × quantité : + au-dessus, − remise.
  double get ecart =>
      prixVendu == null ? 0 : quantite * (prixVendu! - article.prixVenteHabituel);

  bool get depasseStock => quantite > article.quantiteRestante;

  Map<String, dynamic> toJson() => {
        'article_id': article.id,
        'quantite': quantite,
        'prix_vendu': prixVendu,
      };
}

/// Totaux d'une vente en cours.
class TotauxPanier {
  const TotauxPanier({
    required this.total,
    required this.cout,
    required this.ecart,
    required this.nbPieces,
  });

  final double total;
  final double cout;
  final double ecart;
  final int nbPieces;

  double get benefice => total - cout;

  factory TotauxPanier.depuis(Iterable<LignePanier> lignes) {
    var total = 0.0, cout = 0.0, ecart = 0.0;
    var pieces = 0;
    for (final l in lignes) {
      total += l.total;
      cout += l.cout;
      ecart += l.ecart;
      pieces += l.quantite;
    }
    return TotauxPanier(total: total, cout: cout, ecart: ecart, nbPieces: pieces);
  }
}

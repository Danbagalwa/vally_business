import '../../ventes/domain/commande.dart';

/// Ventes et commandes d'une période (annulées exclues), pour l'accueil.
class ResumePeriode {
  const ResumePeriode({required this.nbVentes, required this.totalVendu, required this.benefice});

  final int nbVentes;
  final double totalVendu;
  final double benefice;

  /// [garde] choisit les dates (de vente / de prise de commande) retenues.
  factory ResumePeriode.du(Iterable<Commande> commandes, bool Function(DateTime) garde) {
    var n = 0;
    var total = 0.0, benefice = 0.0;
    for (final c in commandes) {
      if (c.annulee || !garde(c.date)) continue;
      n++;
      total += c.totalArticles;
      benefice += c.benefice;
    }
    return ResumePeriode(nbVentes: n, totalVendu: total, benefice: benefice);
  }
}

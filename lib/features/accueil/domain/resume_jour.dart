import '../../ventes/domain/commande.dart';

/// Ventes d'une période pour l'accueil : annulées et commandes en cours
/// (ni payées, ni livrées) exclues.
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
      if (!c.comptee || !garde(c.date)) continue;
      n++;
      total += c.totalArticles;
      benefice += c.benefice;
    }
    return ResumePeriode(nbVentes: n, totalVendu: total, benefice: benefice);
  }
}

DateTime _jour(DateTime d) => DateTime(d.year, d.month, d.day);

/// Total vendu par jour sur les [jours] derniers jours (aujourd'hui en
/// dernier), ventes comptées seulement — pour la petite courbe de l'accueil.
List<(DateTime, double)> ventesParJour(
  Iterable<Commande> commandes, {
  required DateTime aujourdhui,
  int jours = 7,
}) {
  final fin = _jour(aujourdhui);
  final totaux = {
    for (var i = jours - 1; i >= 0; i--) fin.subtract(Duration(days: i)): 0.0,
  };
  for (final c in commandes) {
    if (!c.comptee) continue;
    final j = _jour(c.date);
    if (totaux.containsKey(j)) totaux[j] = totaux[j]! + c.totalArticles;
  }
  return [for (final MapEntry(key: j, value: v) in totaux.entries) (j, v)];
}

/// « Bonjour », « Bon après-midi » ou « Bonsoir » selon l'heure.
String salutation(DateTime maintenant) => switch (maintenant.hour) {
      < 12 => 'Bonjour',
      < 18 => 'Bon après-midi',
      _ => 'Bonsoir',
    };

/// La phrase du jour, comme on le dirait à voix haute :
/// « Tu as déjà fait 3 ventes aujourd'hui, et 2 commandes t'attendent. »
String phraseDuJour({required int ventes, required int taches}) {
  final debut = ventes == 0
      ? 'Pas encore de vente aujourd’hui'
      : 'Tu as déjà fait $ventes vente${ventes > 1 ? 's' : ''} aujourd’hui';
  final suite = switch ((ventes, taches)) {
    (_, 0) => ventes == 0 ? ', et aucune commande ne t’attend.' : '. Aucune commande ne t’attend.',
    (0, _) => ', mais $taches commande${taches > 1 ? 's' : ''} ${taches > 1 ? 't’attendent' : 't’attend'}.',
    _ => ', et $taches commande${taches > 1 ? 's' : ''} ${taches > 1 ? 't’attendent' : 't’attend'}.',
  };
  return '$debut$suite';
}

/// Ce qu'il reste à faire pour une commande, en commençant par le verbe :
/// « Préparer la commande de Mme Kabila », « Remettre la commande à Papa Jo ».
String tacheCommande(Commande c) => switch (c.statutLivraison) {
      StatutLivraison.prete when c.modeRemise == ModeRemise.livraison => 'Livrer ${c.nomAffiche}',
      StatutLivraison.prete => 'Remettre la commande à ${c.nomAffiche}',
      _ => 'Préparer la commande de ${c.nomAffiche}',
    };

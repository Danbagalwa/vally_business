import '../../stock/domain/article.dart';
import '../../ventes/domain/commande.dart';

double _n(Object? v) => (v as num?)?.toDouble() ?? 0;
int _i(Object? v) => (v as num?)?.toInt() ?? 0;

/// Indicateurs d'une période (fonction SQL dashboard_periode).
class IndicateursPeriode {
  const IndicateursPeriode({
    required this.totalApprovisionne,
    required this.chiffreAffaires,
    required this.coutVentes,
    required this.benefice,
    required this.totalEncaisse,
    required this.resteDu,
    required this.gainAuDessus,
    required this.coutRemises,
    required this.nbCommandes,
    required this.piecesVendues,
  });

  final double totalApprovisionne;
  final double chiffreAffaires;
  final double coutVentes;
  final double benefice;
  final double totalEncaisse;
  final double resteDu;
  final double gainAuDessus;
  final double coutRemises;
  final int nbCommandes;
  final int piecesVendues;

  /// Montant moyen d'une vente (0 s'il n'y en a pas).
  double get panierMoyen => nbCommandes == 0 ? 0 : chiffreAffaires / nbCommandes;

  /// Part du bénéfice dans le total vendu, en % (null sans vente).
  double? get margePourcent => chiffreAffaires == 0 ? null : benefice / chiffreAffaires * 100;

  factory IndicateursPeriode.fromJson(Map<String, dynamic> j) =>
      IndicateursPeriode(
        totalApprovisionne: _n(j['total_approvisionne']),
        chiffreAffaires: _n(j['chiffre_affaires']),
        coutVentes: _n(j['cout_ventes']),
        benefice: _n(j['benefice']),
        totalEncaisse: _n(j['total_encaisse']),
        resteDu: _n(j['reste_du']),
        gainAuDessus: _n(j['gain_au_dessus']),
        coutRemises: _n(j['cout_remises']),
        nbCommandes: _i(j['nb_commandes']),
        piecesVendues: _i(j['pieces_vendues']),
      );
}

/// Indicateurs actuels, depuis l'ouverture (vue v_dashboard).
class IndicateursActuels {
  const IndicateursActuels({
    required this.valeurStockRestant,
    required this.piecesEnStock,
    required this.articlesEpuises,
    required this.beneficeRealise,
    required this.beneficeVerse,
    required this.beneficeDisponible,
    this.beneficeEncaisse = 0,
    required this.resteDu,
  });

  final double valeurStockRestant;
  final int piecesEnStock;
  final int articlesEpuises;
  final double beneficeRealise;

  /// Déjà versé dans Mes dépenses (« Me verser un bénéfice »).
  final double beneficeVerse;
  final double beneficeDisponible;

  /// Bénéfice des ventes payées en entier (seul ce bénéfice peut être versé).
  final double beneficeEncaisse;
  final double resteDu;

  static const vide = IndicateursActuels(
    valeurStockRestant: 0,
    piecesEnStock: 0,
    articlesEpuises: 0,
    beneficeRealise: 0,
    beneficeVerse: 0,
    beneficeDisponible: 0,
    resteDu: 0,
  );

  factory IndicateursActuels.fromJson(Map<String, dynamic> j) =>
      IndicateursActuels(
        valeurStockRestant: _n(j['valeur_stock_restant']),
        piecesEnStock: _i(j['pieces_en_stock']),
        articlesEpuises: _i(j['articles_epuises']),
        beneficeRealise: _n(j['benefice_realise']),
        beneficeVerse: _n(j['benefice_verse']),
        beneficeDisponible: _n(j['benefice_disponible']),
        beneficeEncaisse: _n(j['benefice_encaisse']),
        resteDu: _n(j['reste_du']),
      );
}

/// Article vendu sur une période (fonction SQL articles_vendus_periode).
class ArticleVendu {
  const ArticleVendu({
    required this.articleId,
    required this.nom,
    required this.description,
    this.categorie = '',
    required this.quantite,
    required this.chiffreAffaires,
    required this.benefice,
  });

  final String articleId;
  final String nom;
  final String description;
  final String categorie;
  final int quantite;
  final double chiffreAffaires;
  final double benefice;

  factory ArticleVendu.fromJson(Map<String, dynamic> j) => ArticleVendu(
        articleId: j['article_id'] as String,
        nom: j['nom'] as String,
        description: [j['categorie'], j['taille']].whereType<String>().join(' · '),
        categorie: j['categorie'] as String? ?? '',
        quantite: _i(j['quantite']),
        chiffreAffaires: _n(j['chiffre_affaires']),
        benefice: _n(j['benefice']),
      );
}

/// Un mois du graphique.
class PointMensuel {
  const PointMensuel(this.mois, this.chiffreAffaires, this.benefice);

  final DateTime mois;
  final double chiffreAffaires;
  final double benefice;
}

/// Chiffre d'affaires et bénéfice des [nbMois] derniers mois (mois en cours
/// compris), commandes annulées exclues. Les mois sans vente valent 0.
List<PointMensuel> parMois(
  Iterable<Commande> commandes, {
  required DateTime aujourdhui,
  int nbMois = 6,
}) {
  final mois = [
    for (var i = nbMois - 1; i >= 0; i--)
      DateTime(aujourdhui.year, aujourdhui.month - i),
  ];
  final ca = {for (final m in mois) m: 0.0};
  final benef = {for (final m in mois) m: 0.0};
  for (final c in commandes) {
    if (!c.comptee) continue; // ni annulée, ni commande en cours
    final m = DateTime(c.date.year, c.date.month);
    if (!ca.containsKey(m)) continue;
    ca[m] = ca[m]! + c.total;
    benef[m] = benef[m]! + c.benefice;
  }
  return [for (final m in mois) PointMensuel(m, ca[m]!, benef[m]!)];
}

/// Articles encore en stock qui ne se vendent pas : aucune vente depuis
/// [jours] jours (ou jamais vendus et approvisionnés depuis plus de [jours]
/// jours). Les plus anciens d'abord.
List<Article> articlesQuiNePartentPas(
  Iterable<Article> articles, {
  required DateTime aujourdhui,
  int jours = 30,
  int max = 5,
}) {
  final limite = DateTime(aujourdhui.year, aujourdhui.month, aujourdhui.day - jours);
  DateTime reference(Article a) => a.derniereVente ?? a.dateAppro;
  final lents = articles
      .where((a) => !a.epuise && reference(a).isBefore(limite))
      .toList()
    ..sort((a, b) => reference(a).compareTo(reference(b)));
  return lents.take(max).toList();
}

/// Nombre de jours depuis la dernière vente (ou l'approvisionnement).
int joursSansVente(Article a, DateTime aujourdhui) {
  final ref = a.derniereVente ?? a.dateAppro;
  return DateTime(aujourdhui.year, aujourdhui.month, aujourdhui.day)
      .difference(ref)
      .inDays;
}

/// Variation en % entre deux valeurs (null si la précédente vaut 0 :
/// on ne peut pas calculer de pourcentage).
double? variation(num actuel, num precedent) {
  if (precedent == 0) return null;
  return (actuel - precedent) / precedent.abs() * 100;
}

/// Une catégorie et ce qu'elle a rapporté sur la période.
class PartCategorieVendue {
  const PartCategorieVendue(this.categorie, this.chiffreAffaires, this.quantite, this.part);

  final String categorie;
  final double chiffreAffaires;
  final int quantite;

  /// Part du total vendu, entre 0 et 1.
  final double part;
}

/// Ventes regroupées par catégorie, la plus grosse d'abord.
List<PartCategorieVendue> parCategorie(Iterable<ArticleVendu> articles) {
  final ca = <String, double>{};
  final qte = <String, int>{};
  for (final a in articles) {
    final c = a.categorie.isEmpty ? 'Autre' : a.categorie;
    ca[c] = (ca[c] ?? 0) + a.chiffreAffaires;
    qte[c] = (qte[c] ?? 0) + a.quantite;
  }
  final total = ca.values.fold<double>(0, (s, v) => s + v);
  return [
    for (final MapEntry(key: c, value: v) in ca.entries)
      PartCategorieVendue(c, v, qte[c]!, total == 0 ? 0 : v / total),
  ]..sort((a, b) => b.chiffreAffaires.compareTo(a.chiffreAffaires));
}

import '../../../core/format/dates.dart';

/// En dessous de ce nombre de pièces restantes, le stock est « faible ».
const seuilStockFaible = 2;

/// Article tel que lu dans la vue v_stock (avec ses calculs).
class Article {
  const Article({
    required this.id,
    required this.nom,
    required this.categorie,
    required this.taille,
    this.couleur,
    required this.quantiteAchetee,
    required this.prixAchat,
    required this.prixVenteHabituel,
    this.fournisseur,
    required this.dateAppro,
    this.photoChemin,
    required this.quantiteVendue,
    required this.quantiteRestante,
    required this.totalApprovisionne,
    required this.valeurStockRestant,
    this.derniereVente,
    this.pourEnfant = false,
  });

  final String id;
  final String nom;
  final String categorie;
  final String taille;
  final String? couleur;
  final int quantiteAchetee;

  /// Prix d'achat unitaire, tous frais compris.
  final double prixAchat;
  final double prixVenteHabituel;
  final String? fournisseur;
  final DateTime dateAppro;

  /// Chemin de la photo dans le bucket « photos-articles ».
  final String? photoChemin;

  final int quantiteVendue;
  final int quantiteRestante;
  final double totalApprovisionne;
  final double valeurStockRestant;
  final DateTime? derniereVente;

  /// Vêtement pour enfant (sinon adulte, par défaut).
  final bool pourEnfant;

  bool get epuise => quantiteRestante <= 0;
  bool get stockFaible => !epuise && quantiteRestante <= seuilStockFaible;

  /// Marge prévue par pièce au prix habituel.
  double get margeUnitaire => prixVenteHabituel - prixAchat;

  /// « Robe · M · Rouge »
  String get description =>
      [categorie, taille, if (couleur != null) couleur].join(' · ');

  factory Article.fromJson(Map<String, dynamic> json) => Article(
        id: json['id'] as String,
        nom: json['nom'] as String,
        categorie: json['categorie'] as String,
        taille: json['taille'] as String,
        couleur: json['couleur'] as String?,
        quantiteAchetee: json['quantite_achetee'] as int,
        prixAchat: (json['prix_achat'] as num).toDouble(),
        prixVenteHabituel: (json['prix_vente_habituel'] as num).toDouble(),
        fournisseur: json['fournisseur'] as String?,
        dateAppro: FormatDate.lire(json['date_appro'] as String),
        photoChemin: json['photo_url'] as String?,
        quantiteVendue: json['quantite_vendue'] as int,
        quantiteRestante: json['quantite_restante'] as int,
        totalApprovisionne: (json['total_approvisionne'] as num).toDouble(),
        valeurStockRestant: (json['valeur_stock_restant'] as num).toDouble(),
        derniereVente: json['derniere_vente'] == null
            ? null
            : FormatDate.lire(json['derniere_vente'] as String),
        pourEnfant: json['pour_enfant'] as bool? ?? false,
      );
}

/// Données saisies dans le formulaire d'article (montants déjà convertis
/// dans la devise de référence de la boutique).
class ArticleSaisie {
  const ArticleSaisie({
    required this.nom,
    required this.categorie,
    required this.taille,
    this.couleur,
    required this.quantiteAchetee,
    required this.prixAchat,
    required this.prixVenteHabituel,
    this.fournisseur,
    required this.dateAppro,
    this.pourEnfant = false,
  });

  final String nom;
  final String categorie;
  final String taille;
  final String? couleur;
  final int quantiteAchetee;
  final double prixAchat;
  final double prixVenteHabituel;
  final String? fournisseur;
  final DateTime dateAppro;
  final bool pourEnfant;

  Map<String, dynamic> toJson() => {
        'pour_enfant': pourEnfant,
        'nom': nom.trim(),
        'categorie': categorie.trim(),
        'taille': taille.trim(),
        'couleur': _videEnNull(couleur),
        'quantite_achetee': quantiteAchetee,
        'prix_achat': prixAchat,
        'prix_vente_habituel': prixVenteHabituel,
        'fournisseur': _videEnNull(fournisseur),
        'date_appro': FormatDate.iso(dateAppro),
      };

  static String? _videEnNull(String? texte) {
    final t = texte?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }
}

/// Totaux affichés en haut de l'onglet Stock.
class ResumeStock {
  const ResumeStock({
    required this.totalApprovisionne,
    required this.valeurStockRestant,
    required this.piecesEnStock,
    required this.nbArticles,
    required this.nbEpuises,
    required this.nbStockFaible,
  });

  final double totalApprovisionne;
  final double valeurStockRestant;
  final int piecesEnStock;
  final int nbArticles;
  final int nbEpuises;
  final int nbStockFaible;

  factory ResumeStock.depuis(Iterable<Article> articles) {
    var appro = 0.0, valeur = 0.0;
    var pieces = 0, nb = 0, epuises = 0, faibles = 0;
    for (final a in articles) {
      appro += a.totalApprovisionne;
      valeur += a.valeurStockRestant;
      pieces += a.quantiteRestante;
      nb++;
      if (a.epuise) epuises++;
      if (a.stockFaible) faibles++;
    }
    return ResumeStock(
      totalApprovisionne: appro,
      valeurStockRestant: valeur,
      piecesEnStock: pieces,
      nbArticles: nb,
      nbEpuises: epuises,
      nbStockFaible: faibles,
    );
  }
}

/// Adulte ou enfant (filtre du stock).
enum Public {
  tous('Tous'),
  adulte('Adulte'),
  enfant('Enfant');

  const Public(this.libelle);

  final String libelle;

  bool garde(Article a) => switch (this) {
        tous => true,
        adulte => !a.pourEnfant,
        enfant => a.pourEnfant,
      };
}

/// Tailles proposées selon le public.
const taillesAdulte = ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'Unique'];
const taillesEnfant = [
  '0-3 mois', '3-6 mois', '6-12 mois', '12-18 mois', '2 ans', '3 ans',
  '4 ans', '6 ans', '8 ans', '10 ans', '12 ans', '14 ans',
];

/// Filtre de la liste : texte libre, catégorie, adulte / enfant.
List<Article> filtrerArticles(
  List<Article> articles, {
  String recherche = '',
  String? categorie,
  Public public = Public.tous,
}) {
  final mots = _normaliser(recherche)
      .split(' ')
      .where((m) => m.isNotEmpty)
      .toList();
  return articles.where((a) {
    if (!public.garde(a)) return false;
    if (categorie != null && a.categorie != categorie) return false;
    if (mots.isEmpty) return true;
    final texte = _normaliser(
        '${a.nom} ${a.categorie} ${a.taille} ${a.couleur ?? ''} ${a.fournisseur ?? ''}');
    return mots.every(texte.contains);
  }).toList();
}

/// Catégories présentes, triées.
List<String> categoriesDe(Iterable<Article> articles) =>
    (articles.map((a) => a.categorie).toSet().toList()..sort());

String _normaliser(String texte) {
  const accents = {
    'à': 'a', 'â': 'a', 'ä': 'a', 'ç': 'c', 'é': 'e', 'è': 'e', 'ê': 'e',
    'ë': 'e', 'î': 'i', 'ï': 'i', 'ô': 'o', 'ö': 'o', 'ù': 'u', 'û': 'u',
    'ü': 'u', 'ÿ': 'y', 'œ': 'oe',
  };
  final bas = texte.toLowerCase();
  final sortie = StringBuffer();
  for (final c in bas.split('')) {
    sortie.write(accents[c] ?? c);
  }
  return sortie.toString();
}

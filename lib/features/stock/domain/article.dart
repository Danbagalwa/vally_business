import '../../../core/format/dates.dart';
import '../../../core/format/montant.dart';
import '../../../core/format/texte.dart';
import '../../../core/rayon.dart';

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
    this.nbAchats = 1,
    this.rayon = Rayon.habits,
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

  /// Nombre d'achats : 1 = jamais racheté. Au-delà, quantité et prix
  /// d'achat ne se corrigent plus à la main (voir [Achat]).
  final int nbAchats;

  bool get dejaRachete => nbAchats > 1;

  /// Habits ou parfums : un article vendu ne change plus de rayon.
  final Rayon rayon;

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
        // Absente avant la mise à jour SQL « réapprovisionnement ».
        nbAchats: (json['nb_achats'] as num?)?.toInt() ?? 1,
        rayon: Rayon.depuisCode(json['rayon'] as String?),
      );
}

/// Un achat d'un article : le premier, ou un rachat (table approvisionnements).
class Achat {
  const Achat({
    required this.id,
    required this.date,
    required this.quantite,
    required this.prixAchat,
    this.fournisseur,
    required this.estRachat,
    this.deviseSaisie,
    this.montantSaisi,
    this.tauxChange,
    required this.creeLe,
  });

  final String id;
  final DateTime date;
  final int quantite;

  /// Prix d'une pièce, tous frais compris, en devise de référence.
  final double prixAchat;
  final String? fournisseur;

  /// Faux pour le premier achat (création de l'article).
  final bool estRachat;
  final Devise? deviseSaisie;
  final double? montantSaisi;
  final double? tauxChange;
  final DateTime creeLe;

  double get total => quantite * prixAchat;

  factory Achat.fromJson(Map<String, dynamic> j) => Achat(
        id: j['id'] as String,
        date: FormatDate.lire(j['date_appro'] as String),
        quantite: (j['quantite'] as num).toInt(),
        prixAchat: (j['prix_achat'] as num).toDouble(),
        fournisseur: j['fournisseur'] as String?,
        estRachat: j['prix_moyen_avant'] != null,
        deviseSaisie: j['devise_saisie'] == null ? null : Devise.depuisCode(j['devise_saisie'] as String),
        montantSaisi: (j['montant_saisi'] as num?)?.toDouble(),
        tauxChange: (j['taux_change'] as num?)?.toDouble(),
        creeLe: DateTime.parse(j['created_at'] as String).toLocal(),
      );
}

/// Coût moyen d'une pièce après un rachat, comme la base le calcule :
/// (pièces en boutique × coût actuel + pièces rachetées × nouveau prix)
/// ÷ total des pièces en boutique, arrondi au centime.
double coutMoyenApresRachat({
  required int restant,
  required double coutActuel,
  required int quantite,
  required double prix,
}) {
  final r = restant < 0 ? 0 : restant;
  final total = r + quantite;
  if (total <= 0) return coutActuel;
  return ((r * coutActuel + quantite * prix) / total * 100).round() / 100;
}

/// Où en est l'article, en une phrase : « Il en reste 2 sur 10. »
String phraseResteArticle(Article a) {
  if (!a.epuise) return 'Il en reste ${a.quantiteRestante} sur ${a.quantiteAchetee}.';
  return a.quantiteAchetee == 1
      ? 'Épuisé : la seule pièce est vendue ou réservée.'
      : 'Épuisé : les ${a.quantiteAchetee} pièces sont vendues ou réservées.';
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
    this.rayon = Rayon.habits,
  });

  final Rayon rayon;
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
        'rayon': rayon.code,
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

/// Le stock en une phrase : « 8 pièces en boutique, qui t'ont coûté
/// 80 000 CDF. Depuis le début, tu as investi 200 000 CDF. »
String phraseStock(ResumeStock r, Devise devise) {
  final valeur = FormatMontant.formater(r.valeurStockRestant, devise);
  final investi = FormatMontant.formater(r.totalApprovisionne, devise);
  final enBoutique = switch (r.piecesEnStock) {
    <= 0 => 'Plus aucune pièce en boutique.',
    1 => '1 pièce en boutique, qui t’a coûté $valeur.',
    final n => '$n pièces en boutique, qui t’ont coûté $valeur.',
  };
  return '$enBoutique Depuis le début, tu as investi $investi.';
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

/// Rayon Parfums : catégories et contenances proposées.
const categoriesParfums = [
  'Parfum', 'Eau de parfum', 'Eau de toilette', 'Huile parfumée', 'Coffret', 'Déodorant',
];
const contenancesParfums = ['30 ml', '50 ml', '75 ml', '100 ml', '150 ml', '200 ml'];

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
  final mots = normaliserRecherche(recherche)
      .split(' ')
      .where((m) => m.isNotEmpty)
      .toList();
  return articles.where((a) {
    if (!public.garde(a)) return false;
    if (categorie != null && a.categorie != categorie) return false;
    if (mots.isEmpty) return true;
    final texte = normaliserRecherche(
        '${a.nom} ${a.categorie} ${a.taille} ${a.couleur ?? ''} ${a.fournisseur ?? ''}');
    return mots.every(texte.contains);
  }).toList();
}

/// Catégories présentes, triées.
List<String> categoriesDe(Iterable<Article> articles) =>
    (articles.map((a) => a.categorie).toSet().toList()..sort());

import '../../../core/format/dates.dart';
import '../../../core/format/montant.dart';

/// Vente au comptoir (remise tout de suite) ou commande (remise plus tard).
enum TypeCommande {
  vente('vente'),
  commande('commande');

  const TypeCommande(this.code);

  final String code;

  static TypeCommande depuisCode(String? code) =>
      code == 'commande' ? commande : vente;
}

/// Où en est la remise des articles au client.
enum StatutLivraison {
  enAttente('en_attente', 'À préparer'),
  prete('prete', 'Prête'),
  livree('livree', 'Livrée'),
  annulee('annulee', 'Annulée');

  const StatutLivraison(this.code, this.libelle);

  final String code;
  final String libelle;

  static StatutLivraison depuisCode(String code) =>
      values.firstWhere((s) => s.code == code);
}

enum ModeRemise {
  retrait('retrait', 'Retrait en boutique'),
  livraison('livraison', 'Livraison');

  const ModeRemise(this.code, this.libelle);

  final String code;
  final String libelle;

  static ModeRemise? depuisCode(String? code) =>
      code == null ? null : values.firstWhere((m) => m.code == code);
}

/// Statut de paiement (calculé par la base).
enum StatutPaiement {
  nonPayee('non_payee', 'Non payée'),
  partiellementPayee('partiellement_payee', 'Partiellement payée'),
  soldee('soldee', 'Soldée');

  const StatutPaiement(this.code, this.libelle);

  final String code;
  final String libelle;

  static StatutPaiement depuisCode(String code) =>
      values.firstWhere((s) => s.code == code);
}

enum ModePaiement {
  especes('especes', 'Espèces'),
  mobileMoney('mobile_money', 'Mobile money'),
  virement('virement', 'Virement'),
  autre('autre', 'Autre');

  const ModePaiement(this.code, this.libelle);

  final String code;
  final String libelle;

  static ModePaiement depuisCode(String code) =>
      values.firstWhere((m) => m.code == code, orElse: () => autre);
}

double _nombre(Object? v) => (v as num?)?.toDouble() ?? 0;

DateTime _jour(DateTime d) => DateTime(d.year, d.month, d.day);

/// Vente ou commande, telle que lue dans la vue v_commandes.
class Commande {
  const Commande({
    required this.id,
    this.numero,
    this.type = TypeCommande.vente,
    this.clientId,
    this.clientNom,
    this.clientTelephone,
    required this.date,
    required this.statutLivraison,
    this.note,
    required this.nbPieces,
    required this.total,
    required this.totalArticles,
    required this.cout,
    required this.benefice,
    required this.gainAuDessus,
    required this.coutRemises,
    required this.totalPaye,
    required this.resteAPayer,
    required this.statutPaiement,
    required this.creeLe,
    this.dateLivraison,
    this.modeRemise,
    this.adresseLivraison,
    this.fraisLivraison = 0,
  });

  final String id;

  /// Numéro de facture « 2026-0042 » (attribué par la base).
  final String? numero;
  final TypeCommande type;
  final String? clientId;
  final String? clientNom;
  final String? clientTelephone;

  /// Date de la vente / de la prise de commande.
  final DateTime date;
  final StatutLivraison statutLivraison;
  final String? note;
  final int nbPieces;

  /// Ce que le client doit payer en tout (articles + frais de livraison).
  final double total;
  final double totalArticles;
  final double cout;

  /// Bénéfice sur les articles (les frais de livraison n'en font pas partie).
  final double benefice;
  final double gainAuDessus;
  final double coutRemises;
  final double totalPaye;
  final double resteAPayer;
  final StatutPaiement statutPaiement;
  final DateTime creeLe;

  final DateTime? dateLivraison;
  final ModeRemise? modeRemise;
  final String? adresseLivraison;
  final double fraisLivraison;

  bool get estCommande => type == TypeCommande.commande;
  bool get annulee => statutLivraison == StatutLivraison.annulee;
  bool get livree => statutLivraison == StatutLivraison.livree;

  /// Commande pas encore remise au client (ni livrée, ni annulée).
  bool get aLivrer => estCommande && !annulee && !livree;

  /// Compte comme une vente (totaux, bénéfice, dettes) : vente au comptoir,
  /// ou commande payée en entier ou livrée. Même règle que la colonne
  /// `comptee` de v_commandes.
  bool get comptee =>
      !annulee && (!estCommande || livree || (totalPaye > 0 && totalPaye >= total));

  /// Commande prise mais pas encore vendue (ni payée en entier, ni livrée).
  bool get enCours => estCommande && !annulee && !comptee;

  bool estEnRetard(DateTime aujourdhui) =>
      aLivrer && dateLivraison != null && dateLivraison!.isBefore(_jour(aujourdhui));

  bool estPourLe(DateTime jour) =>
      dateLivraison != null && _jour(dateLivraison!) == _jour(jour);

  double get ecartPrixHabituel => gainAuDessus - coutRemises;

  String get nomAffiche => clientNom ?? 'Client de passage';

  /// Encore de l'argent à recevoir (non annulée).
  bool get aEncaisser => !annulee && resteAPayer > 0;

  factory Commande.fromJson(Map<String, dynamic> json) => Commande(
        id: json['id'] as String,
        numero: json['numero'] as String?,
        type: TypeCommande.depuisCode(json['type'] as String?),
        clientId: json['client_id'] as String?,
        clientNom: json['client_nom'] as String?,
        clientTelephone: json['client_telephone'] as String?,
        date: FormatDate.lire(json['date_commande'] as String),
        statutLivraison:
            StatutLivraison.depuisCode(json['statut_livraison'] as String),
        note: json['note'] as String?,
        nbPieces: (json['nb_pieces'] as num?)?.toInt() ?? 0,
        total: _nombre(json['total']),
        totalArticles: json.containsKey('total_articles')
            ? _nombre(json['total_articles'])
            : _nombre(json['total']),
        cout: _nombre(json['cout']),
        benefice: _nombre(json['benefice']),
        gainAuDessus: _nombre(json['gain_au_dessus']),
        coutRemises: _nombre(json['cout_remises']),
        totalPaye: _nombre(json['total_paye']),
        resteAPayer: _nombre(json['reste_a_payer']),
        statutPaiement:
            StatutPaiement.depuisCode(json['statut_paiement'] as String),
        creeLe: DateTime.parse(json['created_at'] as String).toLocal(),
        dateLivraison: json['date_livraison'] == null
            ? null
            : FormatDate.lire(json['date_livraison'] as String),
        modeRemise: ModeRemise.depuisCode(json['mode_remise'] as String?),
        adresseLivraison: json['adresse_livraison'] as String?,
        fraisLivraison: _nombre(json['frais_livraison']),
      );
}

/// Ligne d'une vente ou commande (prix figés au moment de la vente).
class LigneCommande {
  const LigneCommande({
    required this.id,
    required this.articleId,
    required this.articleNom,
    required this.articleDescription,
    required this.quantite,
    required this.prixVendu,
    required this.prixAchat,
    this.prixHabituel,
  });

  final String id;
  final String articleId;
  final String articleNom;
  final String articleDescription;
  final int quantite;
  final double prixVendu;
  final double prixAchat;
  final double? prixHabituel;

  double get total => quantite * prixVendu;
  double get benefice => quantite * (prixVendu - prixAchat);

  /// (prix vendu − prix habituel) × quantité.
  double get ecart =>
      prixHabituel == null ? 0 : quantite * (prixVendu - prixHabituel!);

  factory LigneCommande.fromJson(Map<String, dynamic> json) {
    final article = json['articles'] as Map<String, dynamic>? ?? const {};
    return LigneCommande(
      id: json['id'] as String,
      articleId: json['article_id'] as String,
      articleNom: article['nom'] as String? ?? 'Article supprimé',
      articleDescription: [
        article['categorie'],
        article['taille'],
        article['couleur'],
      ].whereType<String>().join(' · '),
      quantite: json['quantite'] as int,
      prixVendu: _nombre(json['prix_vendu']),
      prixAchat: _nombre(json['prix_achat_snapshot']),
      prixHabituel: (json['prix_habituel_snapshot'] as num?)?.toDouble(),
    );
  }
}

class Paiement {
  const Paiement({
    required this.id,
    required this.montant,
    required this.date,
    required this.mode,
    required this.deviseSaisie,
    required this.montantSaisi,
    this.tauxChange,
  });

  final String id;

  /// Montant en devise de référence.
  final double montant;
  final DateTime date;
  final ModePaiement mode;
  final Devise deviseSaisie;
  final double montantSaisi;
  final double? tauxChange;

  bool get converti => tauxChange != null;

  factory Paiement.fromJson(Map<String, dynamic> json) => Paiement(
        id: json['id'] as String,
        montant: _nombre(json['montant']),
        date: FormatDate.lire(json['date_paiement'] as String),
        mode: ModePaiement.depuisCode(json['mode'] as String),
        deviseSaisie: Devise.depuisCode(json['devise_saisie'] as String),
        montantSaisi: _nombre(json['montant_saisi']),
        tauxChange: (json['taux_change'] as num?)?.toDouble(),
      );
}

class Client {
  const Client({required this.id, required this.nom, this.telephone});

  final String id;
  final String nom;
  final String? telephone;

  factory Client.fromJson(Map<String, dynamic> json) => Client(
        id: json['id'] as String,
        nom: json['nom'] as String,
        telephone: json['telephone'] as String?,
      );
}

/// Vente ou commande avec ses lignes et ses paiements (écran de détail).
class CommandeDetail {
  const CommandeDetail({
    required this.commande,
    required this.lignes,
    required this.paiements,
  });

  final Commande commande;
  final List<LigneCommande> lignes;
  final List<Paiement> paiements;
}

// ─── Filtres ──────────────────────────────────────────────────────────

/// Filtres de l'onglet Ventes (ventes au comptoir).
enum FiltreVentes {
  toutes('Toutes'),
  nonPayees('Non payées'),
  annulees('Annulées');

  const FiltreVentes(this.libelle);

  final String libelle;

  bool garde(Commande c) => switch (this) {
        toutes => true,
        nonPayees => c.aEncaisser,
        annulees => c.annulee,
      };
}

/// Filtres de l'onglet Commandes (selon la date de livraison).
enum FiltreCommandes {
  aujourdhui('Aujourd’hui'),
  enRetard('En retard'),
  aVenir('À venir'),
  livrees('Livrées'),
  annulees('Annulées');

  const FiltreCommandes(this.libelle);

  final String libelle;

  bool garde(Commande c, DateTime maintenant) {
    final jour = _jour(maintenant);
    final date = c.dateLivraison == null ? null : _jour(c.dateLivraison!);
    return switch (this) {
      aujourdhui => c.aLivrer && date == jour,
      enRetard => c.estEnRetard(jour),
      aVenir => c.aLivrer && date != null && date.isAfter(jour),
      livrees => c.livree,
      annulees => c.annulee,
    };
  }
}

bool _correspond(Commande c, String recherche) {
  final r = recherche.trim().toLowerCase();
  if (r.isEmpty) return true;
  return c.nomAffiche.toLowerCase().contains(r) ||
      (c.clientTelephone ?? '')
          .replaceAll(' ', '')
          .contains(r.replaceAll(' ', ''));
}

/// Ventes au comptoir filtrées, les plus récentes d'abord.
List<Commande> filtrerVentes(
  List<Commande> toutes, {
  FiltreVentes filtre = FiltreVentes.toutes,
  String recherche = '',
}) =>
    toutes
        .where((c) => !c.estCommande && filtre.garde(c) && _correspond(c, recherche))
        .toList();

/// Commandes filtrées, triées par date de livraison (les plus proches
/// d'abord ; livrées et annulées : les plus récentes d'abord).
/// Si [jour] est donné, toutes les commandes à livrer ce jour-là.
List<Commande> filtrerCommandes(
  List<Commande> toutes, {
  required DateTime aujourdhui,
  FiltreCommandes filtre = FiltreCommandes.aujourdhui,
  DateTime? jour,
  String recherche = '',
}) {
  final liste = toutes.where((c) {
    if (!c.estCommande || !_correspond(c, recherche)) return false;
    if (jour != null) return c.estPourLe(jour) && !c.annulee;
    return filtre.garde(c, aujourdhui);
  }).toList();
  final recentes =
      filtre == FiltreCommandes.livrees || filtre == FiltreCommandes.annulees;
  liste.sort((a, b) {
    final da = a.dateLivraison ?? a.date, db = b.dateLivraison ?? b.date;
    return recentes && jour == null ? db.compareTo(da) : da.compareTo(db);
  });
  return liste;
}

/// Nombre de commandes par filtre (pour les pastilles).
Map<FiltreCommandes, int> compterCommandes(
        List<Commande> toutes, DateTime aujourdhui) =>
    {
      for (final f in FiltreCommandes.values)
        f: toutes.where((c) => c.estCommande && f.garde(c, aujourdhui)).length,
    };

/// Regroupe par jour en gardant l'ordre de la liste.
Map<DateTime, List<Commande>> grouperParJour(
  List<Commande> liste,
  DateTime Function(Commande) date,
) {
  final groupes = <DateTime, List<Commande>>{};
  for (final c in liste) {
    groupes.putIfAbsent(_jour(date(c)), () => []).add(c);
  }
  return groupes;
}

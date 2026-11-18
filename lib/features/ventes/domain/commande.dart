import '../../../core/format/dates.dart';
import '../../../core/format/montant.dart';

/// Statut de livraison (choisi par l'utilisateur).
enum StatutLivraison {
  enAttente('en_attente', 'En attente'),
  livree('livree', 'Livrée'),
  annulee('annulee', 'Annulée');

  const StatutLivraison(this.code, this.libelle);

  final String code;
  final String libelle;

  static StatutLivraison depuisCode(String code) =>
      values.firstWhere((s) => s.code == code);
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

/// Commande telle que lue dans la vue v_commandes (totaux calculés).
class Commande {
  const Commande({
    required this.id,
    this.clientId,
    this.clientNom,
    this.clientTelephone,
    required this.date,
    required this.statutLivraison,
    this.note,
    required this.nbPieces,
    required this.total,
    required this.cout,
    required this.benefice,
    required this.gainAuDessus,
    required this.coutRemises,
    required this.totalPaye,
    required this.resteAPayer,
    required this.statutPaiement,
    required this.creeLe,
  });

  final String id;
  final String? clientId;
  final String? clientNom;
  final String? clientTelephone;
  final DateTime date;
  final StatutLivraison statutLivraison;
  final String? note;
  final int nbPieces;
  final double total;
  final double cout;
  final double benefice;
  final double gainAuDessus;
  final double coutRemises;
  final double totalPaye;
  final double resteAPayer;
  final StatutPaiement statutPaiement;
  final DateTime creeLe;

  bool get annulee => statutLivraison == StatutLivraison.annulee;

  /// Écart total par rapport aux prix habituels (+ au-dessus, − remises).
  double get ecartPrixHabituel => gainAuDessus - coutRemises;

  String get nomAffiche => clientNom ?? 'Client de passage';

  /// Encore de l'argent à recevoir (commande non annulée).
  bool get aEncaisser => !annulee && resteAPayer > 0;

  factory Commande.fromJson(Map<String, dynamic> json) => Commande(
        id: json['id'] as String,
        clientId: json['client_id'] as String?,
        clientNom: json['client_nom'] as String?,
        clientTelephone: json['client_telephone'] as String?,
        date: FormatDate.lire(json['date_commande'] as String),
        statutLivraison:
            StatutLivraison.depuisCode(json['statut_livraison'] as String),
        note: json['note'] as String?,
        nbPieces: (json['nb_pieces'] as num?)?.toInt() ?? 0,
        total: _nombre(json['total']),
        cout: _nombre(json['cout']),
        benefice: _nombre(json['benefice']),
        gainAuDessus: _nombre(json['gain_au_dessus']),
        coutRemises: _nombre(json['cout_remises']),
        totalPaye: _nombre(json['total_paye']),
        resteAPayer: _nombre(json['reste_a_payer']),
        statutPaiement:
            StatutPaiement.depuisCode(json['statut_paiement'] as String),
        creeLe: DateTime.parse(json['created_at'] as String).toLocal(),
      );
}

/// Ligne d'une commande (prix figés au moment de la vente).
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

  /// Ce que le client a réellement donné.
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

/// Commande avec ses lignes et ses paiements (écran de détail).
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

/// Filtres de la liste des ventes.
enum FiltreVentes {
  toutes('Toutes'),
  aEncaisser('À encaisser'),
  soldees('Soldées'),
  aLivrer('À livrer'),
  annulees('Annulées');

  const FiltreVentes(this.libelle);

  final String libelle;

  bool garde(Commande c) => switch (this) {
        toutes => true,
        aEncaisser => c.aEncaisser,
        soldees => !c.annulee && c.statutPaiement == StatutPaiement.soldee,
        aLivrer => c.statutLivraison == StatutLivraison.enAttente,
        annulees => c.annulee,
      };
}

/// Filtre texte (client, téléphone) + filtre de statut.
List<Commande> filtrerCommandes(
  List<Commande> commandes, {
  FiltreVentes filtre = FiltreVentes.toutes,
  String recherche = '',
}) {
  final r = recherche.trim().toLowerCase();
  return commandes.where((c) {
    if (!filtre.garde(c)) return false;
    if (r.isEmpty) return true;
    return c.nomAffiche.toLowerCase().contains(r) ||
        (c.clientTelephone ?? '').replaceAll(' ', '').contains(r.replaceAll(' ', ''));
  }).toList();
}

import '../../../core/format/dates.dart';
import '../../../core/format/montant.dart';

enum TypeMouvement {
  entree('entree', 'Entrée'),
  sortie('sortie', 'Sortie');

  const TypeMouvement(this.code, this.libelle);

  final String code;
  final String libelle;

  static TypeMouvement depuisCode(String code) => code == 'entree' ? entree : sortie;
}

/// Catégories proposées (la saisie libre reste possible).
const categoriesSortie = [
  'Loyer', 'Nourriture', 'Transport', 'Factures', 'Santé', 'École',
  'Famille', 'Salaire', 'Autre',
];
const categoriesEntree = ['Salaire', 'Cadeau', 'Remboursement', 'Autre'];

double _n(Object? v) => (v as num?)?.toDouble() ?? 0;

/// Entrée ou sortie d'argent dans Mes dépenses.
class Mouvement {
  const Mouvement({
    required this.id,
    required this.type,
    required this.montant,
    required this.categorie,
    required this.date,
    this.note,
    required this.depuisBoutique,
    required this.deviseSaisie,
    required this.montantSaisi,
    this.tauxChange,
    required this.creeLe,
  });

  final String id;
  final TypeMouvement type;

  /// Montant en devise de référence.
  final double montant;
  final String categorie;
  final DateTime date;
  final String? note;

  /// Versement de bénéfice (« Me verser un bénéfice »).
  final bool depuisBoutique;
  final Devise deviseSaisie;
  final double montantSaisi;
  final double? tauxChange;
  final DateTime creeLe;

  bool get estEntree => type == TypeMouvement.entree;

  /// Montant signé : + pour une entrée, − pour une sortie.
  double get signe => estEntree ? montant : -montant;

  factory Mouvement.fromJson(Map<String, dynamic> j) => Mouvement(
        id: j['id'] as String,
        type: TypeMouvement.depuisCode(j['type'] as String),
        montant: _n(j['montant']),
        categorie: j['categorie'] as String,
        date: FormatDate.lire(j['date_mouvement'] as String),
        note: j['note'] as String?,
        depuisBoutique: j['source'] == 'boutique',
        deviseSaisie: Devise.depuisCode(j['devise_saisie'] as String),
        montantSaisi: _n(j['montant_saisi']),
        tauxChange: (j['taux_change'] as num?)?.toDouble(),
        creeLe: DateTime.parse(j['created_at'] as String).toLocal(),
      );
}

/// Saisie d'un mouvement manuel (la base convertit dans la devise de référence).
class MouvementSaisie {
  const MouvementSaisie({
    required this.type,
    required this.montantSaisi,
    required this.devise,
    required this.categorie,
    required this.date,
    this.note,
  });

  final TypeMouvement type;
  final double montantSaisi;
  final Devise devise;
  final String categorie;
  final DateTime date;
  final String? note;

  Map<String, dynamic> toJson() => {
        'type': type.code,
        'montant_saisi': montantSaisi,
        'devise_saisie': devise.code,
        'categorie': categorie.trim(),
        'date_mouvement': FormatDate.iso(date),
        'note': (note == null || note!.trim().isEmpty) ? null : note!.trim(),
      };
}

/// Entrées, sorties et solde d'un ensemble de mouvements.
class Bilan {
  const Bilan({required this.entrees, required this.sorties});

  final double entrees;
  final double sorties;

  double get solde => entrees - sorties;

  factory Bilan.de(Iterable<Mouvement> mouvements) {
    var e = 0.0, s = 0.0;
    for (final m in mouvements) {
      if (m.estEntree) {
        e += m.montant;
      } else {
        s += m.montant;
      }
    }
    return Bilan(entrees: e, sorties: s);
  }
}

/// Une catégorie de sorties et sa part du total.
class PartCategorie {
  const PartCategorie(this.categorie, this.montant, this.part);

  final String categorie;
  final double montant;

  /// Entre 0 et 1.
  final double part;
}

/// Sorties regroupées par catégorie, la plus grosse d'abord.
List<PartCategorie> repartitionSorties(Iterable<Mouvement> mouvements) {
  final totaux = <String, double>{};
  for (final m in mouvements.where((m) => !m.estEntree)) {
    totaux[m.categorie] = (totaux[m.categorie] ?? 0) + m.montant;
  }
  final total = totaux.values.fold<double>(0, (s, v) => s + v);
  final parts = [
    for (final MapEntry(key: c, value: v) in totaux.entries)
      PartCategorie(c, v, total == 0 ? 0 : v / total),
  ]..sort((a, b) => b.montant.compareTo(a.montant));
  return parts;
}

/// Mouvements d'un mois donné (les plus récents d'abord).
List<Mouvement> duMois(Iterable<Mouvement> mouvements, DateTime mois) => mouvements
    .where((m) => m.date.year == mois.year && m.date.month == mois.month)
    .toList()
  ..sort((a, b) {
    final d = b.date.compareTo(a.date);
    return d != 0 ? d : b.creeLe.compareTo(a.creeLe);
  });

/// Un mois de la vue v_flux_mensuel.
class FluxMensuel {
  const FluxMensuel({
    required this.mois,
    required this.entrees,
    required this.sorties,
    required this.soldeCumule,
  });

  final DateTime mois;
  final double entrees;
  final double sorties;
  final double soldeCumule;

  double get solde => entrees - sorties;

  factory FluxMensuel.fromJson(Map<String, dynamic> j) => FluxMensuel(
        mois: FormatDate.lire(j['mois'] as String),
        entrees: _n(j['entrees']),
        sorties: _n(j['sorties']),
        soldeCumule: _n(j['solde_cumule']),
      );
}

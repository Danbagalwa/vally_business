import '../../../core/format/montant.dart';

/// Boutique partagée par ses membres.
class Boutique {
  const Boutique({
    required this.id,
    required this.nom,
    required this.devise,
    required this.tauxUsdCdf,
    required this.tauxMajLe,
  });

  final String id;
  final String nom;

  /// Devise dans laquelle tous les montants sont enregistrés.
  final Devise devise;

  /// 1 USD = [tauxUsdCdf] CDF.
  final double tauxUsdCdf;
  final DateTime tauxMajLe;

  factory Boutique.fromJson(Map<String, dynamic> json) => Boutique(
        id: json['id'] as String,
        nom: json['nom'] as String,
        devise: Devise.depuisCode(json['devise_reference'] as String),
        tauxUsdCdf: (json['taux_usd_cdf'] as num).toDouble(),
        tauxMajLe: DateTime.parse(json['taux_maj_le'] as String).toLocal(),
      );
}

/// Membre d'une boutique (tous admins).
class Membre {
  const Membre({
    required this.userId,
    required this.email,
    required this.depuis,
    required this.estMoi,
  });

  final String userId;
  final String email;
  final DateTime depuis;
  final bool estMoi;

  factory Membre.fromJson(Map<String, dynamic> json) => Membre(
        userId: json['user_id'] as String,
        email: json['email'] as String? ?? '',
        depuis: DateTime.parse(json['created_at'] as String).toLocal(),
        estMoi: json['est_moi'] as bool? ?? false,
      );
}

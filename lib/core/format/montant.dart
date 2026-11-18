import 'package:intl/intl.dart';

/// Devises gérées par la boutique. Le taux de change USD → CDF sera
/// configurable (stocké côté Supabase, étape C).
enum Devise {
  cdf('CDF', 0),
  usd('USD', 2);

  const Devise(this.code, this.decimales);

  final String code;
  final int decimales;

  static Devise depuisCode(String code) =>
      Devise.values.firstWhere((d) => d.code == code);

  /// L'autre devise (CDF ↔ USD).
  Devise get autre => this == Devise.cdf ? Devise.usd : Devise.cdf;
}

enum ArrondiDevise { proche, haut, bas }

/// Sens d'un montant, pour choisir le signe affiché.
enum SensMontant {
  /// Montant neutre : pas de signe.
  neutre,

  /// Bénéfice, entrée d'argent : toujours « + ».
  positif,

  /// Sortie, reste à payer, remise : toujours « − ».
  negatif,
}

/// Formatage des montants à la française : espaces fines pour les milliers,
/// virgule décimale, code devise après le nombre (« 125 000 CDF », « 12,50 USD »).
abstract final class FormatMontant {
  static const _moins = '−'; // vrai signe moins « − »
  static const _espace = ' '; // espace fine insécable

  static final _formats = <Devise, NumberFormat>{};

  static NumberFormat _format(Devise devise) => _formats.putIfAbsent(
        devise,
        () => NumberFormat.decimalPatternDigits(
          locale: 'fr',
          decimalDigits: devise.decimales,
        ),
      );

  /// Ex. : `formater(125000, Devise.cdf, sens: SensMontant.positif)`
  /// → « + 125 000 CDF ».
  static String formater(
    num montant,
    Devise devise, {
    SensMontant sens = SensMontant.neutre,
  }) {
    final valeur = _format(devise)
        .format(montant.abs())
        .replaceAll(' ', _espace);
    final signe = switch (sens) {
      SensMontant.positif => '+$_espace',
      SensMontant.negatif => '$_moins$_espace',
      SensMontant.neutre => montant < 0 ? '$_moins$_espace' : '',
    };
    return '$signe$valeur$_espace${devise.code}';
  }

  /// Lit un montant saisi : « 15 000 », « 12,5 », « 12.50 » → nombre.
  /// Retourne null si la saisie est vide ou invalide.
  static double? lire(String saisie) {
    final propre = saisie
        .replaceAll(RegExp(r'[\s  ]'), '')
        .replaceAll(',', '.');
    if (propre.isEmpty) return null;
    return double.tryParse(propre);
  }

  /// Valeur à pré-remplir dans un champ : « 15000 », « 12,50 ».
  static String pourSaisie(num montant, Devise devise) {
    if (devise.decimales == 0) return montant.round().toString();
    return montant.toStringAsFixed(devise.decimales).replaceAll('.', ',');
  }

  /// Arrondi à 2 décimales (précision des colonnes numeric(14,2)).
  static double arrondir(num montant) => (montant * 100).round() / 100;

  /// Arrondi à la précision de la devise (CDF : unité, USD : centime).
  /// [ArrondiDevise.haut] pour un montant à payer (le client ne reste
  /// jamais débiteur de quelques francs), [ArrondiDevise.bas] pour un
  /// plafond (on ne dépasse jamais le disponible).
  static double arrondirPour(num montant, Devise devise,
      [ArrondiDevise mode = ArrondiDevise.proche]) {
    final f = devise.decimales == 0 ? 1 : 100;
    final v = montant * f;
    // Petite marge pour les erreurs de virgule flottante (10.000000001).
    final r = switch (mode) {
      ArrondiDevise.proche => v.round(),
      ArrondiDevise.haut => (v - 1e-6).ceil(),
      ArrondiDevise.bas => (v + 1e-6).floor(),
    };
    return r / f;
  }

  /// Conversion selon un taux « 1 USD = [tauxUsdVersCdf] CDF ».
  static num convertir(
    num montant, {
    required Devise de,
    required Devise vers,
    required num tauxUsdVersCdf,
  }) {
    if (de == vers) return montant;
    return de == Devise.usd
        ? montant * tauxUsdVersCdf
        : montant / tauxUsdVersCdf;
  }
}

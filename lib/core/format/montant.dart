import 'package:intl/intl.dart';

/// Devises gérées par la boutique. Le taux de change USD → CDF sera
/// configurable (stocké côté Supabase, étape C).
enum Devise {
  cdf('CDF', 0),
  usd('USD', 2);

  const Devise(this.code, this.decimales);

  final String code;
  final int decimales;
}

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

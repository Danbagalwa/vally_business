import 'package:intl/intl.dart';

import '../../../core/format/dates.dart';

enum TypePeriode {
  ceMois('Ce mois'),
  moisDernier('Mois dernier'),
  cetteAnnee('Cette année'),
  personnalisee('Personnalisée');

  const TypePeriode(this.libelle);

  final String libelle;
}

/// Période du tableau de bord (bornes incluses, dates sans heure).
class Periode {
  const Periode._(this.type, this.debut, this.fin);

  final TypePeriode type;
  final DateTime debut;
  final DateTime fin;

  factory Periode.de(TypePeriode type, {DateTime? aujourdhui}) {
    final a = aujourdhui ?? DateTime.now();
    return switch (type) {
      TypePeriode.ceMois =>
        Periode._(type, DateTime(a.year, a.month), DateTime(a.year, a.month + 1, 0)),
      TypePeriode.moisDernier =>
        Periode._(type, DateTime(a.year, a.month - 1), DateTime(a.year, a.month, 0)),
      TypePeriode.cetteAnnee =>
        Periode._(type, DateTime(a.year), DateTime(a.year, 12, 31)),
      TypePeriode.personnalisee =>
        Periode._(type, DateTime(a.year, a.month, a.day), DateTime(a.year, a.month, a.day)),
    };
  }

  factory Periode.personnalisee(DateTime debut, DateTime fin) => Periode._(
        TypePeriode.personnalisee,
        DateTime(debut.year, debut.month, debut.day),
        DateTime(fin.year, fin.month, fin.day),
      );

  /// Période de comparaison, de même durée et juste avant :
  /// • ce mois (en cours) → les mêmes jours du mois dernier (1 → aujourd'hui) ;
  /// • cette année (en cours) → l'an dernier jusqu'à la même date ;
  /// • mois dernier → le mois d'avant ;
  /// • personnalisée → autant de jours, juste avant.
  Periode precedente({DateTime? aujourdhui}) {
    final a = aujourdhui ?? DateTime.now();
    switch (type) {
      case TypePeriode.ceMois:
        final dernierJour = DateTime(debut.year, debut.month, 0).day;
        final jour = a.day < dernierJour ? a.day : dernierJour;
        return Periode.personnalisee(
            DateTime(debut.year, debut.month - 1), DateTime(debut.year, debut.month - 1, jour));
      case TypePeriode.cetteAnnee:
        return Periode.personnalisee(DateTime(debut.year - 1), DateTime(a.year - 1, a.month, a.day));
      case TypePeriode.moisDernier:
        return Periode._(TypePeriode.moisDernier, DateTime(debut.year, debut.month - 1),
            DateTime(debut.year, debut.month, 0));
      case TypePeriode.personnalisee:
        final jours = fin.difference(debut).inDays;
        final nouvelleFin = debut.subtract(const Duration(days: 1));
        return Periode.personnalisee(nouvelleFin.subtract(Duration(days: jours)), nouvelleFin);
    }
  }

  /// « novembre 2026 », « 2026 », « 3 nov. 2026 – 18 nov. 2026 ».
  String get libelle => switch (type) {
        TypePeriode.ceMois || TypePeriode.moisDernier =>
          DateFormat('MMMM y', 'fr').format(debut),
        TypePeriode.cetteAnnee => '${debut.year}',
        TypePeriode.personnalisee => debut == fin
            ? FormatDate.court(debut)
            : '${FormatDate.court(debut)} – ${FormatDate.court(fin)}',
      };

  @override
  bool operator ==(Object other) =>
      other is Periode &&
      other.type == type &&
      other.debut == debut &&
      other.fin == fin;

  @override
  int get hashCode => Object.hash(type, debut, fin);
}

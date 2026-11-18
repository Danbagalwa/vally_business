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

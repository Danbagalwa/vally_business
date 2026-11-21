import 'package:intl/intl.dart';

/// Formatage des dates en français (nécessite initializeDateFormatting('fr')).
abstract final class FormatDate {
  static final _court = DateFormat('d MMM y', 'fr');
  static final _jourMois = DateFormat('EEE d MMM', 'fr');
  static final _heure = DateFormat('HH:mm', 'fr');
  static final _iso = DateFormat('yyyy-MM-dd');

  /// « 16 nov. 2026 »
  static String court(DateTime date) => _court.format(date);

  /// « 14:32 »
  static String heure(DateTime date) => _heure.format(date);

  /// « 2026-11-16 » (format attendu par Supabase pour une colonne date).
  static String iso(DateTime date) => _iso.format(date);

  static DateTime lire(String iso) => DateTime.parse(iso);

  static DateTime jour(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Depuis quand, dit simplement : « aujourd'hui », « hier »,
  /// « il y a 3 jours », « le 12 nov. » (année ajoutée si elle diffère).
  static String ilYa(DateTime date, {DateTime? aujourdhui}) {
    final a = jour(aujourdhui ?? DateTime.now());
    final d = jour(date);
    final n = a.difference(d).inDays;
    if (n <= 0) return 'aujourd’hui';
    if (n == 1) return 'hier';
    if (n < 7) return 'il y a $n jours';
    final texte = DateFormat('d MMM', 'fr').format(d);
    return d.year == a.year ? 'le $texte' : 'le $texte ${d.year}';
  }

  /// « Aujourd'hui », « Demain », « Hier », « lun. 24 nov. »
  /// (l'année n'est ajoutée que si elle diffère).
  static String relatif(DateTime date, {DateTime? aujourdhui}) {
    final a = jour(aujourdhui ?? DateTime.now());
    final d = jour(date);
    final ecart = d.difference(a).inDays;
    if (ecart == 0) return 'Aujourd’hui';
    if (ecart == 1) return 'Demain';
    if (ecart == -1) return 'Hier';
    final texte = _jourMois.format(d);
    return d.year == a.year ? texte : '$texte ${d.year}';
  }
}

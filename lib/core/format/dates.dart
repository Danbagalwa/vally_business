import 'package:intl/intl.dart';

/// Formatage des dates en français (nécessite initializeDateFormatting('fr')).
abstract final class FormatDate {
  static final _court = DateFormat('d MMM y', 'fr');
  static final _iso = DateFormat('yyyy-MM-dd');

  /// « 16 nov. 2026 »
  static String court(DateTime date) => _court.format(date);

  /// « 2026-11-16 » (format attendu par Supabase pour une colonne date).
  static String iso(DateTime date) => _iso.format(date);

  static DateTime lire(String iso) => DateTime.parse(iso);
}

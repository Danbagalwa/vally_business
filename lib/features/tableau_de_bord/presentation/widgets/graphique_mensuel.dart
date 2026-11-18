import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/format/montant.dart';
import '../../../../core/widgets/montant_texte.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/indicateurs.dart';

enum _Mesure { benefice, ventes }

/// Évolution sur 6 mois : une seule série (bénéfice OU ventes), mois en
/// cours en couleur pleine, les autres atténués ; info-bulle au toucher ;
/// vue tableau pour l'accessibilité.
class GraphiqueMensuel extends StatefulWidget {
  const GraphiqueMensuel({super.key, required this.points, required this.devise});

  final List<PointMensuel> points;
  final Devise devise;

  @override
  State<GraphiqueMensuel> createState() => _GraphiqueMensuelState();
}

class _GraphiqueMensuelState extends State<GraphiqueMensuel> {
  bool _tableau = false;
  _Mesure _mesure = _Mesure.benefice;

  static final _mois = DateFormat('MMM', 'fr');
  static final _moisAnnee = DateFormat('MMMM y', 'fr');
  static final _compact = NumberFormat.compact(locale: 'fr');

  double _valeur(PointMensuel p) => _mesure == _Mesure.benefice ? p.benefice : p.chiffreAffaires;

  SensMontant _sens(double v) => _mesure == _Mesure.ventes
      ? SensMontant.neutre
      : (v > 0 ? SensMontant.positif : (v < 0 ? SensMontant.negatif : SensMontant.neutre));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(_mesure == _Mesure.benefice ? 'Bénéfice par mois' : 'Ventes par mois',
                    style: theme.textTheme.titleMedium),
              ),
              IconButton(
                tooltip: _tableau ? 'Voir le graphique' : 'Voir en tableau',
                icon: Icon(_tableau ? Icons.bar_chart : Icons.table_rows_outlined, size: 20),
                onPressed: () => setState(() => _tableau = !_tableau),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SegmentedButton<_Mesure>(
                segments: const [
                  ButtonSegment(value: _Mesure.benefice, label: Text('Bénéfice')),
                  ButtonSegment(value: _Mesure.ventes, label: Text('Ventes')),
                ],
                selected: {_mesure},
                showSelectedIcon: false,
                onSelectionChanged: (s) {
                  HapticFeedback.selectionClick();
                  setState(() => _mesure = s.first);
                },
              ),
            ),
            const SizedBox(height: 4),
            Text('6 derniers mois · ventes annulées et commandes en cours exclues',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _tableau
                  ? KeyedSubtree(key: const ValueKey('tableau'), child: _vueTableau(theme))
                  : KeyedSubtree(key: ValueKey(_mesure), child: _vueGraphique(theme)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vueTableau(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(children: [
        for (final p in widget.points.reversed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              Expanded(child: Text(_moisAnnee.format(p.mois), style: theme.textTheme.bodyMedium)),
              MontantTexte(_valeur(p).abs(),
                  devise: widget.devise, sens: _sens(_valeur(p)), style: theme.textTheme.bodyMedium),
            ]),
          ),
      ]),
    );
  }

  Widget _vueGraphique(ThemeData theme) {
    final vally = theme.extension<VallyColors>()!;
    final encre = theme.colorScheme.onSurfaceVariant;
    final grille = theme.colorScheme.outlineVariant.withValues(alpha: 0.6);
    final valeurs = widget.points.map(_valeur).toList();
    final maxY = valeurs.fold<double>(0, (m, v) => v > m ? v : m);
    final minY = valeurs.fold<double>(0, (m, v) => v < m ? v : m);
    final etendue = (maxY - minY) == 0 ? 1.0 : (maxY - minY);
    final pas = _pasLisible(etendue / 3);
    final dernier = widget.points.length - 1;

    return SizedBox(
      height: 190,
      child: BarChart(
        BarChartData(
          maxY: maxY == 0 && minY == 0 ? pas : (maxY / pas).ceil() * pas,
          minY: minY < 0 ? (minY / pas).floor() * pas : 0,
          alignment: BarChartAlignment.spaceAround,
          borderData: FlBorderData(show: true, border: Border(bottom: BorderSide(color: grille))),
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: pas,
            getDrawingHorizontalLine: (_) => FlLine(color: grille, strokeWidth: 1, dashArray: [3, 3]),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: pas,
                getTitlesWidget: (v, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(_compact.format(v),
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: encre, fontFeatures: const [FontFeature.tabularFigures()])),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= widget.points.length) return const SizedBox.shrink();
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(_mois.format(widget.points[i].mois),
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: i == dernier ? theme.colorScheme.onSurface : encre,
                            fontWeight: i == dernier ? FontWeight.w700 : FontWeight.w500)),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchCallback: (evenement, reponse) {
              if (evenement is FlTapDownEvent && reponse?.spot != null) {
                HapticFeedback.selectionClick();
              }
            },
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => theme.colorScheme.inverseSurface,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItem: (groupe, _, _, _) {
                final p = widget.points[groupe.x];
                final v = _valeur(p);
                final surInverse = theme.colorScheme.onInverseSurface;
                return BarTooltipItem(
                  '${_moisAnnee.format(p.mois)}\n',
                  theme.textTheme.labelSmall!.copyWith(color: surInverse),
                  children: [
                    TextSpan(
                      text: FormatMontant.formater(v.abs(), widget.devise, sens: _sens(v)),
                      style: theme.textTheme.labelLarge!.copyWith(
                          color: surInverse, fontFeatures: const [FontFeature.tabularFigures()]),
                    ),
                  ],
                );
              },
            ),
          ),
          barGroups: [
            for (final (i, p) in widget.points.indexed)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: _valeur(p),
                    width: 18,
                    // Mois en cours en couleur pleine, les autres atténués.
                    color: i == dernier ? vally.graphique : vally.graphique.withValues(alpha: 0.45),
                    borderRadius: _valeur(p) >= 0
                        ? const BorderRadius.vertical(top: Radius.circular(4))
                        : const BorderRadius.vertical(bottom: Radius.circular(4)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// Pas de graduation « rond » : 1, 2 ou 5 × 10^n.
  static double _pasLisible(double brut) {
    if (brut <= 0) return 1;
    var puissance = 1.0;
    while (puissance * 10 <= brut) {
      puissance *= 10;
    }
    while (puissance > brut) {
      puissance /= 10;
    }
    for (final m in [1, 2, 5, 10]) {
      if (m * puissance >= brut) return m * puissance;
    }
    return 10 * puissance;
  }
}

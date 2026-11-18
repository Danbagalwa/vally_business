import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/format/montant.dart';
import '../../../../core/widgets/montant_texte.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/indicateurs.dart';

/// Bénéfice par mois : une seule série (le titre la nomme, pas de légende),
/// barres fines à bout arrondi, grille discrète, info-bulle au toucher,
/// et vue tableau pour l'accessibilité.
class GraphiqueMensuel extends StatefulWidget {
  const GraphiqueMensuel({super.key, required this.points, required this.devise});

  final List<PointMensuel> points;
  final Devise devise;

  @override
  State<GraphiqueMensuel> createState() => _GraphiqueMensuelState();
}

class _GraphiqueMensuelState extends State<GraphiqueMensuel> {
  bool _tableau = false;

  static final _mois = DateFormat('MMM', 'fr');
  static final _compact = NumberFormat.compact(locale: 'fr');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            VallySpace.s4, VallySpace.s2, VallySpace.s2, VallySpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text('Bénéfice par mois',
                    style: theme.textTheme.titleMedium),
              ),
              IconButton(
                tooltip: _tableau ? 'Voir le graphique' : 'Voir en tableau',
                icon: Icon(_tableau
                    ? Icons.bar_chart
                    : Icons.table_rows_outlined),
                onPressed: () => setState(() => _tableau = !_tableau),
              ),
            ]),
            Text('6 derniers mois, ventes annulées exclues',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: VallySpace.s4),
            _tableau ? _vueTableau(theme) : _vueGraphique(theme),
          ],
        ),
      ),
    );
  }

  Widget _vueTableau(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(right: VallySpace.s2),
      child: Column(
        children: [
          for (final p in widget.points.reversed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: VallySpace.s1),
              child: Row(children: [
                Expanded(
                  child: Text(DateFormat('MMMM y', 'fr').format(p.mois),
                      style: theme.textTheme.bodyMedium),
                ),
                MontantTexte(
                  p.benefice.abs(),
                  devise: widget.devise,
                  sens: p.benefice > 0
                      ? SensMontant.positif
                      : (p.benefice < 0 ? SensMontant.negatif : SensMontant.neutre),
                  style: theme.textTheme.bodyMedium,
                ),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _vueGraphique(ThemeData theme) {
    final vally = theme.extension<VallyColors>()!;
    final encre = theme.colorScheme.onSurfaceVariant;
    final grille = theme.colorScheme.outlineVariant;
    final valeurs = widget.points.map((p) => p.benefice).toList();
    final maxY = valeurs.fold<double>(0, (m, v) => v > m ? v : m);
    final minY = valeurs.fold<double>(0, (m, v) => v < m ? v : m);
    final etendue = (maxY - minY) == 0 ? 1.0 : (maxY - minY);
    final pas = _pasLisible(etendue / 3);

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          maxY: maxY == 0 && minY == 0 ? pas : (maxY / pas).ceil() * pas,
          minY: minY < 0 ? (minY / pas).floor() * pas : 0,
          alignment: BarChartAlignment.spaceAround,
          borderData: FlBorderData(
            show: true,
            border: Border(bottom: BorderSide(color: grille)),
          ),
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: pas,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: grille, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: pas,
                getTitlesWidget: (v, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(_compact.format(v),
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: encre,
                          fontFeatures: const [FontFeature.tabularFigures()])),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= widget.points.length) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(_mois.format(widget.points[i].mois),
                        style: theme.textTheme.labelSmall?.copyWith(color: encre)),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => theme.colorScheme.inverseSurface,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItem: (groupe, _, barre, _) {
                final p = widget.points[groupe.x];
                return BarTooltipItem(
                  '${DateFormat('MMMM y', 'fr').format(p.mois)}\n',
                  theme.textTheme.labelSmall!
                      .copyWith(color: theme.colorScheme.onInverseSurface),
                  children: [
                    TextSpan(
                      text: FormatMontant.formater(
                          p.benefice.abs(), widget.devise,
                          sens: p.benefice > 0
                              ? SensMontant.positif
                              : (p.benefice < 0
                                  ? SensMontant.negatif
                                  : SensMontant.neutre)),
                      style: theme.textTheme.labelLarge!.copyWith(
                          color: theme.colorScheme.onInverseSurface,
                          fontFeatures: const [FontFeature.tabularFigures()]),
                    ),
                    TextSpan(
                      text: '\nVentes : ${FormatMontant.formater(p.chiffreAffaires, widget.devise)}',
                      style: theme.textTheme.labelSmall!
                          .copyWith(color: theme.colorScheme.onInverseSurface),
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
                    toY: p.benefice,
                    width: 16,
                    color: vally.graphique,
                    // Bout arrondi côté données, base droite sur l'axe.
                    borderRadius: p.benefice >= 0
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

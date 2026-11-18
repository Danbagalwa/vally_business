import 'package:material_ui/material_ui.dart';

import '../../../../core/format/montant.dart';
import '../../../../core/widgets/montant_texte.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/article.dart';

/// Résumé du stock : valeur restante, total investi, pièces, alertes.
class CarteResumeStock extends StatelessWidget {
  const CarteResumeStock({super.key, required this.resume, required this.devise});

  final ResumeStock resume;
  final Devise devise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vally = theme.extension<VallyColors>()!;
    final alertes = resume.nbEpuises + resume.nbStockFaible;
    Widget bloc(String libelle, Widget valeur) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(libelle, style: theme.textTheme.bodySmall),
            const SizedBox(height: 2),
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: valeur),
          ]),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            bloc('Valeur du stock',
                MontantTexte(resume.valeurStockRestant, devise: devise, style: theme.textTheme.titleMedium)),
            bloc('Investi', MontantTexte(resume.totalApprovisionne, devise: devise, style: theme.textTheme.bodyMedium)),
            bloc('Pièces', Text('${resume.piecesEnStock}', style: theme.textTheme.bodyMedium)),
          ]),
          if (alertes > 0) ...[
            const SizedBox(height: 10),
            Row(children: [
              Icon(Icons.warning_amber_rounded, size: 16, color: vally.attention),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  [
                    if (resume.nbEpuises > 0)
                      '${resume.nbEpuises} épuisé${resume.nbEpuises > 1 ? 's' : ''}',
                    if (resume.nbStockFaible > 0)
                      '${resume.nbStockFaible} bientôt épuisé${resume.nbStockFaible > 1 ? 's' : ''}',
                  ].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(color: vally.attention),
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';

import '../../../../core/format/montant.dart';
import '../../../../core/widgets/montant_texte.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/article.dart';

/// Carte du haut de l'onglet Stock : valeur du stock et total investi.
class CarteResumeStock extends StatelessWidget {
  const CarteResumeStock({super.key, required this.resume, required this.devise});

  final ResumeStock resume;
  final Devise devise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vally = theme.extension<VallyColors>()!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(VallySpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Valeur du stock restant', style: theme.textTheme.bodySmall),
            const SizedBox(height: VallySpace.s1),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: MontantTexte(resume.valeurStockRestant,
                  devise: devise,
                  style: theme.textTheme.displaySmall?.copyWith(fontSize: 32)),
            ),
            const SizedBox(height: VallySpace.s4),
            Row(
              children: [
                Expanded(
                  child: _Indicateur(
                    libelle: 'Total approvisionné',
                    valeur: MontantTexte(resume.totalApprovisionne, devise: devise),
                  ),
                ),
                Expanded(
                  child: _Indicateur(
                    libelle: 'Pièces en stock',
                    valeur: Text('${resume.piecesEnStock}',
                        style: theme.textTheme.titleSmall),
                  ),
                ),
              ],
            ),
            if (resume.nbEpuises + resume.nbStockFaible > 0) ...[
              const SizedBox(height: VallySpace.s4),
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 18, color: vally.attention),
                  const SizedBox(width: VallySpace.s2),
                  Expanded(
                    child: Text(
                      [
                        if (resume.nbEpuises > 0)
                          '${resume.nbEpuises} épuisé${resume.nbEpuises > 1 ? 's' : ''}',
                        if (resume.nbStockFaible > 0)
                          '${resume.nbStockFaible} bientôt épuisé${resume.nbStockFaible > 1 ? 's' : ''}',
                      ].join(' · '),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: vally.attention),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Indicateur extends StatelessWidget {
  const _Indicateur({required this.libelle, required this.valeur});

  final String libelle;
  final Widget valeur;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(libelle, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: VallySpace.s1),
        FittedBox(fit: BoxFit.scaleDown, child: valeur),
      ],
    );
  }
}

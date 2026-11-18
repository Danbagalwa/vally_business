import 'package:material_ui/material_ui.dart';

import '../../../../core/format/dates.dart';
import '../../../../core/format/montant.dart';
import '../../../../core/widgets/montant_texte.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/commande.dart';
import 'badges_commande.dart';

/// Ligne de la liste des ventes.
class CommandeTuile extends StatelessWidget {
  const CommandeTuile({
    super.key,
    required this.commande,
    required this.devise,
    this.onTap,
  });

  final Commande commande;
  final Devise devise;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final barre = commande.annulee
        ? TextDecoration.lineThrough
        : TextDecoration.none;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(VallySpace.s4 - VallySpace.s1),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(commande.nomAffiche,
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(
                      '${FormatDate.court(commande.date)} · '
                      '${commande.nbPieces} pièce${commande.nbPieces > 1 ? 's' : ''}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: VallySpace.s2),
                    Wrap(
                      spacing: VallySpace.s2,
                      runSpacing: VallySpace.s1,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        BadgePaiement(commande: commande, devise: devise),
                        if (!commande.annulee)
                          PastilleLivraison(statut: commande.statutLivraison),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: VallySpace.s2),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  MontantTexte(commande.total,
                      devise: devise,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(decoration: barre)),
                  if (!commande.annulee && commande.benefice != 0)
                    MontantTexte(
                      commande.benefice.abs(),
                      devise: devise,
                      sens: commande.benefice > 0
                          ? SensMontant.positif
                          : SensMontant.negatif,
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

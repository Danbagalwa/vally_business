import 'package:material_ui/material_ui.dart';

import '../../../../core/format/montant.dart';
import '../../../../core/widgets/elements.dart';
import '../../../../core/widgets/montant_texte.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/commande.dart';

/// Statut de paiement selon la charte : soldée en vert (✓),
/// non payée / reste à payer en ambre (icône, « − »).
class BadgePaiement extends StatelessWidget {
  const BadgePaiement({super.key, required this.commande, required this.devise});

  final Commande commande;
  final Devise devise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vally = theme.extension<VallyColors>()!;
    if (commande.annulee) {
      return const Pastille(texte: 'Annulée', icone: Icons.block);
    }
    return switch (commande.statutPaiement) {
      StatutPaiement.soldee =>
        Pastille(texte: 'Payée', icone: Icons.check, couleur: vally.benefice),
      StatutPaiement.nonPayee =>
        Pastille(texte: 'Non payée', icone: Icons.schedule, couleur: vally.attention),
      StatutPaiement.partiellementPayee => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: vally.attention.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(VallyRadius.sm),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.timelapse, size: 13, color: vally.attention),
            const SizedBox(width: 4),
            Flexible(
              child: TexteAvecMontants(
                ['Reste ', spanMontant(context, commande.resteAPayer, devise, sens: SensMontant.negatif)],
                maxLines: 1,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: vally.attention, fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        ),
    };
  }
}

/// Statut de remise d'une commande.
class PastilleLivraison extends StatelessWidget {
  const PastilleLivraison({super.key, required this.statut});

  final StatutLivraison statut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vally = theme.extension<VallyColors>()!;
    return switch (statut) {
      StatutLivraison.enAttente => Pastille(
          texte: statut.libelle,
          icone: Icons.inventory_outlined,
          couleur: theme.colorScheme.onPrimaryContainer,
          fond: theme.colorScheme.primaryContainer),
      StatutLivraison.prete => Pastille(
          texte: statut.libelle,
          icone: Icons.shopping_bag_outlined,
          couleur: theme.colorScheme.onPrimaryContainer,
          fond: theme.colorScheme.primaryContainer),
      StatutLivraison.livree =>
        Pastille(texte: statut.libelle, icone: Icons.check, couleur: vally.benefice),
      StatutLivraison.annulee =>
        Pastille(texte: statut.libelle, icone: Icons.block),
    };
  }
}

/// « + 5 000 CDF au-dessus du prix habituel » / « − 2 000 CDF de remise ».
class TexteEcart extends StatelessWidget {
  const TexteEcart({super.key, required this.ecart, required this.devise, this.style});

  final double ecart;
  final Devise devise;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    if (ecart.abs() < 0.005) return const SizedBox.shrink();
    final base = style ?? Theme.of(context).textTheme.bodySmall;
    final positif = ecart > 0;
    return TexteAvecMontants([
      spanMontant(context, ecart.abs(), devise,
          sens: positif ? SensMontant.positif : SensMontant.negatif),
      positif ? ' au-dessus du prix habituel' : ' de remise',
    ], style: base);
  }
}

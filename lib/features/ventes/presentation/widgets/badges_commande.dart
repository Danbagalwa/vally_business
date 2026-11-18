import 'package:material_ui/material_ui.dart';

import '../../../../core/format/montant.dart';
import '../../../../core/widgets/montant_texte.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/commande.dart';

/// Statut de paiement selon la charte :
/// soldée en vert (icône ✓), non payée / reste à payer en ambre (icône, « − »).
class BadgePaiement extends StatelessWidget {
  const BadgePaiement({super.key, required this.commande, required this.devise});

  final Commande commande;
  final Devise devise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vally = theme.extension<VallyColors>()!;
    final style = theme.textTheme.bodySmall;

    if (commande.annulee) {
      return _Ligne(
        icone: Icons.block,
        couleur: theme.colorScheme.onSurfaceVariant,
        enfant: Text('Annulée', style: style),
      );
    }
    return switch (commande.statutPaiement) {
      StatutPaiement.soldee => _Ligne(
          icone: Icons.check_circle_outline,
          couleur: vally.benefice,
          enfant: Text('Soldée', style: style?.copyWith(color: vally.benefice)),
        ),
      StatutPaiement.nonPayee => _Ligne(
          icone: Icons.schedule,
          couleur: vally.attention,
          enfant: Text('Non payée', style: style?.copyWith(color: vally.attention)),
        ),
      StatutPaiement.partiellementPayee => _Ligne(
          icone: Icons.timelapse,
          couleur: vally.attention,
          enfant: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Reste ', style: style?.copyWith(color: vally.attention)),
              MontantTexte(commande.resteAPayer,
                  devise: devise, sens: SensMontant.negatif, style: style),
            ],
          ),
        ),
    };
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({required this.icone, required this.couleur, required this.enfant});

  final IconData icone;
  final Color couleur;
  final Widget enfant;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icone, size: 16, color: couleur),
        const SizedBox(width: VallySpace.s1),
        Flexible(child: enfant),
      ],
    );
  }
}

/// Pastille du statut de livraison.
class PastilleLivraison extends StatelessWidget {
  const PastilleLivraison({super.key, required this.statut});

  final StatutLivraison statut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icone, fond, texte) = switch (statut) {
      StatutLivraison.enAttente => (
          Icons.inventory_outlined,
          theme.colorScheme.primaryContainer,
          theme.colorScheme.onPrimaryContainer
        ),
      StatutLivraison.livree => (
          Icons.local_shipping_outlined,
          theme.colorScheme.surfaceContainer,
          theme.colorScheme.onSurfaceVariant
        ),
      StatutLivraison.annulee => (
          Icons.block,
          theme.colorScheme.surfaceContainer,
          theme.colorScheme.onSurfaceVariant
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: VallySpace.s2, vertical: 2),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(VallyRadius.sm),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 14, color: texte),
          const SizedBox(width: VallySpace.s1),
          Text(statut.libelle,
              style: theme.textTheme.labelSmall?.copyWith(color: texte)),
        ],
      ),
    );
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MontantTexte(ecart.abs(),
            devise: devise,
            sens: positif ? SensMontant.positif : SensMontant.negatif,
            style: base),
        Flexible(
          child: Text(positif ? ' au-dessus du prix habituel' : ' de remise',
              style: base),
        ),
      ],
    );
  }
}

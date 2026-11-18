import 'package:material_ui/material_ui.dart';

import '../../../../core/format/dates.dart';
import '../../../../core/format/montant.dart';
import '../../../../core/widgets/elements.dart';
import '../../../../core/widgets/montant_texte.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/commande.dart';
import 'badges_commande.dart';

/// Ligne compacte d'une vente au comptoir.
class VenteTuile extends StatelessWidget {
  const VenteTuile({super.key, required this.vente, required this.devise, this.onTap});

  final Commande vente;
  final Devise devise;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = vente;
    return ListTile(
      onTap: onTap,
      leading: AvatarInitiales(_initiales(c.clientNom), taille: 36),
      title: Text(c.nomAffiche, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
          '${FormatDate.heure(c.creeLe)} · ${c.nbPieces} pièce${c.nbPieces > 1 ? 's' : ''}'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          MontantTexte(c.total,
              devise: devise,
              style: theme.textTheme.titleSmall?.copyWith(
                  decoration: c.annulee ? TextDecoration.lineThrough : null)),
          if (c.annulee || c.statutPaiement != StatutPaiement.soldee) ...[
            const SizedBox(height: 2),
            BadgePaiement(commande: c, devise: devise),
          ],
        ],
      ),
    );
  }
}

/// Carte d'une commande à livrer, avec l'action suivante en un geste.
class CommandeCarte extends StatelessWidget {
  const CommandeCarte({
    super.key,
    required this.commande,
    required this.devise,
    this.onTap,
    this.onAvancer,
    this.aujourdhui,
  });

  final Commande commande;
  final Devise devise;
  final VoidCallback? onTap;

  /// Passe au statut suivant (À préparer → Prête → Livrée).
  final VoidCallback? onAvancer;
  final DateTime? aujourdhui;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vally = theme.extension<VallyColors>()!;
    final c = commande;
    final retard = c.estEnRetard(aujourdhui ?? DateTime.now());
    final livraison = c.modeRemise == ModeRemise.livraison;
    final suivant = switch (c.statutLivraison) {
      StatutLivraison.enAttente => 'Marquer prête',
      StatutLivraison.prete => 'Marquer livrée',
      _ => null,
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(c.nomAffiche,
                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                MontantTexte(c.total, devise: devise, style: theme.textTheme.titleSmall),
                const SizedBox(width: 8),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Icon(livraison ? Icons.local_shipping_outlined : Icons.storefront_outlined,
                    size: 15, color: retard ? vally.attention : theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    [
                      if (c.dateLivraison != null) FormatDate.relatif(c.dateLivraison!, aujourdhui: aujourdhui),
                      if (livraison) (c.adresseLivraison ?? 'Livraison') else 'Retrait',
                      '${c.nbPieces} pièce${c.nbPieces > 1 ? 's' : ''}',
                    ].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: retard ? vally.attention : null),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: Wrap(spacing: 6, runSpacing: 4, children: [
                    PastilleLivraison(statut: c.statutLivraison),
                    if (!c.annulee && c.statutPaiement != StatutPaiement.soldee)
                      BadgePaiement(commande: c, devise: devise),
                  ]),
                ),
                if (suivant != null && onAvancer != null)
                  TextButton(
                    onPressed: onAvancer,
                    style: TextButton.styleFrom(
                        minimumSize: const Size(40, 32),
                        visualDensity: VisualDensity.compact),
                    child: Text(suivant),
                  ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

String _initiales(String? nom) {
  if (nom == null || nom.trim().isEmpty) return '';
  return nom.trim().split(RegExp(r'\s+')).take(2).map((m) => m[0].toUpperCase()).join();
}

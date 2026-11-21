import 'package:material_ui/material_ui.dart';

import '../../../../core/format/dates.dart';
import '../../../../core/format/montant.dart';
import '../../../../core/widgets/montant_texte.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/commande.dart';

/// Espace insécable : « 2 » et « pièces » restent sur la même ligne.
final _insecable = String.fromCharCode(0xA0);

/// « 1 pièce », « 2 pièces ».
String _pieces(int n) => '$n${_insecable}pièce${n > 1 ? 's' : ''}';

/// Une ligne du cahier de caisse : l'heure, le client, le montant, et
/// dessous ce qu'il reste à encaisser.
class VenteTuile extends StatelessWidget {
  const VenteTuile({super.key, required this.vente, required this.devise, this.onTap});

  final Commande vente;
  final Devise devise;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final c = vente;
    // Client de passage : écrit plus discrètement qu'un client connu.
    final passage = c.clientNom == null;
    final petit = theme.textTheme.bodySmall?.copyWith(fontSize: 12.5);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        // Heure, nom et montant sur la même ligne de base (tous en 14 px).
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 50,
            child: Text(
              FormatDate.heure(c.creeLe),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                c.nomAffiche,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: passage ? FontWeight.w400 : FontWeight.w600,
                  color: passage ? scheme.onSurfaceVariant : null,
                ),
              ),
              const SizedBox(height: 2),
              Text(_pieces(c.nbPieces), style: petit),
            ]),
          ),
          const SizedBox(width: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              MontantTexte(c.total,
                  devise: devise,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.annulee ? scheme.onSurfaceVariant : null,
                    decoration: c.annulee ? TextDecoration.lineThrough : null,
                  )),
              if (c.annulee || c.statutPaiement != StatutPaiement.soldee) ...[
                const SizedBox(height: 2),
                EtatPaiementTexte(commande: c, devise: devise, style: petit),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

/// État du paiement en quelques mots, sans pastille :
/// « reste − 12 000 CDF » (ambre), « non payée » (ambre), « payée » (vert),
/// « annulée » (gris).
class EtatPaiementTexte extends StatelessWidget {
  const EtatPaiementTexte({super.key, required this.commande, required this.devise, this.style});

  final Commande commande;
  final Devise devise;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vally = theme.extension<VallyColors>()!;
    final base = (style ?? theme.textTheme.bodySmall)?.copyWith(fontWeight: FontWeight.w600);
    final c = commande;
    if (c.annulee) {
      return Text('annulée', style: base?.copyWith(color: theme.colorScheme.onSurfaceVariant));
    }
    return switch (c.statutPaiement) {
      StatutPaiement.soldee => Text('payée', style: base?.copyWith(color: vally.benefice)),
      StatutPaiement.nonPayee => Text('non payée', style: base?.copyWith(color: vally.attention)),
      StatutPaiement.partiellementPayee => TexteAvecMontants(
          ['reste ', spanMontant(context, c.resteAPayer, devise, sens: SensMontant.negatif)],
          maxLines: 1,
          style: base?.copyWith(color: vally.attention),
        ),
    };
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
    final scheme = theme.colorScheme;
    final vally = theme.extension<VallyColors>()!;
    final c = commande;
    final maintenant = aujourdhui ?? DateTime.now();
    final retard = c.estEnRetard(maintenant);
    final joursRetard = !retard || c.dateLivraison == null
        ? 0
        : DateUtils.dateOnly(maintenant).difference(DateUtils.dateOnly(c.dateLivraison!)).inDays;
    final livraison = c.modeRemise == ModeRemise.livraison;
    final suivant = switch (c.statutLivraison) {
      StatutLivraison.enAttente => 'Marquer prête',
      StatutLivraison.prete => 'Marquer livrée',
      _ => null,
    };
    final couleurEtat = switch (c.statutLivraison) {
      StatutLivraison.livree => vally.benefice,
      StatutLivraison.annulee => scheme.onSurfaceVariant,
      _ => scheme.primary,
    };
    final petit = theme.textTheme.bodySmall?.copyWith(fontSize: 12.5);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c.nomAffiche,
                        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(
                      [
                        // La date est déjà dans le titre du groupe : seul le retard est rappelé.
                        if (joursRetard > 0) 'En retard de $joursRetard jour${joursRetard > 1 ? 's' : ''}',
                        if (livraison) (c.adresseLivraison ?? 'Livraison') else 'Retrait en boutique',
                        _pieces(c.nbPieces),
                      ].join(' · '),
                      style: petit?.copyWith(
                        color: retard ? vally.attention : null,
                        fontWeight: retard ? FontWeight.w600 : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ]),
                ),
                const SizedBox(width: 12),
                // Montant, et en dessous ce qu'il reste à payer (comme pour une vente).
                // Largeur bornée : le nom du client garde toujours de la place.
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: MontantTexte(c.total, devise: devise, style: theme.textTheme.titleSmall),
                      ),
                      if (!c.annulee && c.statutPaiement != StatutPaiement.soldee) ...[
                        const SizedBox(height: 3),
                        EtatPaiementTexte(commande: c, devise: devise, style: petit),
                      ],
                    ]),
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                // Point de couleur + état de la commande.
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: couleurEtat, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(c.statutLivraison.libelle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: petit?.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w600)),
                ),
                if (suivant != null && onAvancer != null)
                  TextButton(
                    onPressed: onAvancer,
                    style: TextButton.styleFrom(
                        minimumSize: const Size(40, 32),
                        visualDensity: VisualDensity.compact),
                    child: Text(suivant),
                  )
                else
                  const SizedBox(height: 32),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

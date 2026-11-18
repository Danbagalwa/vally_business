import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/elements.dart';
import '../../../core/widgets/page_erreur.dart';
import '../../stock/data/stock_repository.dart';
import '../data/ventes_repository.dart';
import '../domain/commande.dart';

/// Statut suivant d'une commande : À préparer → Prête → Livrée.
StatutLivraison? statutSuivant(StatutLivraison s) => switch (s) {
      StatutLivraison.enAttente => StatutLivraison.prete,
      StatutLivraison.prete => StatutLivraison.livree,
      _ => null,
    };

/// Recharge tout ce qui dépend des ventes (listes, stock, clients, stats).
void rafraichirVentes(WidgetRef ref, {String? commandeId}) {
  ref.invalidate(commandesProvider);
  ref.invalidate(articlesProvider);
  if (commandeId != null) ref.invalidate(commandeDetailProvider(commandeId));
}

/// Change le statut d'une commande et affiche le résultat.
Future<void> changerStatut(
  BuildContext context,
  WidgetRef ref,
  Commande c,
  StatutLivraison statut,
) async {
  if (statut == StatutLivraison.annulee) {
    final ok = await confirmer(
      context,
      titre: c.estCommande ? 'Annuler la commande ?' : 'Annuler la vente ?',
      message: 'Les articles reviennent en stock et ne comptent plus '
          'dans tes bénéfices.'
          '${c.totalPaye > 0 ? ' Pense à rendre l’argent déjà reçu.' : ''}',
      bouton: c.estCommande ? 'Annuler la commande' : 'Annuler la vente',
      destructif: true,
    );
    if (!ok) return;
  }
  try {
    await ref.read(ventesRepositoryProvider).changerStatutLivraison(c.id, statut);
    rafraichirVentes(ref, commandeId: c.id);
    if (context.mounted) {
      afficherSucces(context, switch (statut) {
        StatutLivraison.prete => '${c.nomAffiche} : commande prête.',
        StatutLivraison.livree => '${c.nomAffiche} : commande livrée.',
        StatutLivraison.annulee => 'Annulée : le stock est remis.',
        StatutLivraison.enAttente => 'Commande remise à préparer.',
      });
    }
  } catch (e) {
    if (context.mounted) afficherErreur(context, e);
  }
}

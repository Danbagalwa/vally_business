import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/contact.dart';
import '../../../core/format/dates.dart';
import '../../../core/format/montant.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/elements.dart';
import '../../../core/widgets/montant_texte.dart';
import '../../../core/widgets/page_erreur.dart';
import '../../../theme/app_theme.dart';
import '../../boutique/data/boutique_repository.dart';
import '../../ventes/data/ventes_repository.dart';
import '../../ventes/domain/commande.dart';
import '../../ventes/presentation/actions_commande.dart';
import '../../ventes/presentation/widgets/badges_commande.dart';
import '../../ventes/presentation/widgets/saisie_paiement.dart';
import '../data/clients_repository.dart';
import '../domain/client_resume.dart';
import 'fiche_client_dialogue.dart';

/// Fiche d'un client : contact, ce qu'il doit, historique.
class ClientDetailPage extends ConsumerWidget {
  const ClientDetailPage({super.key, required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clients = ref.watch(clientsResumeProvider);
    final commandes = ref.watch(commandesProvider);
    return clients.when(
      skipLoadingOnRefresh: true,
      loading: () => Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
          appBar: AppBar(),
          body: PageErreur(erreur: e, onReessayer: () => ref.invalidate(clientsResumeProvider))),
      data: (liste) {
        final client = liste.where((c) => c.id == clientId).firstOrNull;
        if (client == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('Ce client n’existe plus.')));
        }
        final achats = (commandes.value ?? const <Commande>[])
            .where((c) => c.clientId == clientId)
            .toList();
        return _Fiche(client: client, achats: achats);
      },
    );
  }
}

class _Fiche extends ConsumerWidget {
  const _Fiche({required this.client, required this.achats});

  final ClientResume client;
  final List<Commande> achats;

  Future<void> _modifier(BuildContext context, WidgetRef ref) async {
    final saisie = await demanderFicheClient(context, nom: client.nom, telephone: client.telephone);
    if (saisie == null) return;
    try {
      await ref.read(clientsRepositoryProvider).modifier(client.id, nom: saisie.nom, telephone: saisie.telephone);
      ref.invalidate(clientsResumeProvider);
      ref.invalidate(commandesProvider);
    } catch (e) {
      if (context.mounted) afficherErreur(context, e);
    }
  }

  Future<void> _supprimer(BuildContext context, WidgetRef ref) async {
    final ok = await confirmer(
      context,
      titre: 'Supprimer ce client ?',
      message: 'Ses ventes et commandes restent, sans nom de client.',
      bouton: 'Supprimer',
      destructif: true,
    );
    if (!ok) return;
    try {
      await ref.read(clientsRepositoryProvider).supprimer(client.id);
      ref.invalidate(clientsResumeProvider);
      ref.invalidate(commandesProvider);
      if (context.mounted) context.pop();
    } catch (e) {
      if (context.mounted) afficherErreur(context, e);
    }
  }

  Future<void> _encaisser(BuildContext context, WidgetRef ref, Commande c) async {
    final b = ref.read(boutiqueActiveProvider);
    final p = await demanderPaiement(context,
        resteAPayer: c.resteAPayer, deviseReference: b.devise, tauxUsdCdf: b.tauxUsdCdf);
    if (p == null) return;
    try {
      await ref.read(ventesRepositoryProvider).ajouterPaiement(
          c.id,
          PaiementSaisi(montantSaisi: p.montantSaisi, devise: p.devise, mode: p.mode, date: p.date));
      rafraichirVentes(ref, commandeId: c.id);
      if (context.mounted) afficherSucces(context, 'Paiement enregistré.');
    } catch (e) {
      if (context.mounted) afficherErreur(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final devise = ref.watch(boutiqueActiveProvider).devise;
    final c = client;
    final impayes = achats.where((a) => a.aEncaisser && a.comptee).toList();
    final enCours = achats.where((a) => a.enCours).toList();
    final rappel = c.doit
        ? 'Bonjour ${c.nom}, petit rappel de Vally Business : il reste '
            '${FormatMontant.formater(c.totalDu, devise)} à régler. Merci.'
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Client'),
        actions: [
          IconButton(
              tooltip: 'Modifier', icon: const Icon(Icons.edit_outlined),
              onPressed: () => _modifier(context, ref)),
          PopupMenuButton<String>(
            tooltip: 'Plus d’actions',
            onSelected: (_) => _supprimer(context, ref),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'supprimer',
                child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_outline),
                    title: Text('Supprimer le client')),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(VallySpace.s4, VallySpace.s2, VallySpace.s4, VallySpace.s6),
        children: [
          Row(children: [
            AvatarInitiales(c.initiales, taille: 56),
            const SizedBox(width: VallySpace.s4),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.nom, style: theme.textTheme.headlineSmall),
                if (c.telephone != null) Text(c.telephone!, style: theme.textTheme.bodyMedium),
              ]),
            ),
          ]),
          if (c.telephone != null) ...[
            const SizedBox(height: VallySpace.s4),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => appeler(context, c.telephone!),
                  icon: const Icon(Icons.call_outlined, size: 18),
                  label: const Text('Appeler'),
                ),
              ),
              const SizedBox(width: VallySpace.s2),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => ouvrirWhatsApp(context, c.telephone!, message: rappel),
                  icon: const Icon(Icons.chat_outlined, size: 18),
                  label: Text(c.doit ? 'Relancer' : 'WhatsApp'),
                ),
              ),
            ]),
          ],
          const SizedBox(height: VallySpace.s4),
          Row(children: [
            Expanded(
              child: _Chiffre(
                libelle: 'Il te doit',
                valeur: MontantTexte(c.totalDu,
                    devise: devise,
                    sens: c.doit ? SensMontant.negatif : SensMontant.neutre,
                    style: theme.textTheme.titleMedium),
              ),
            ),
            const SizedBox(width: VallySpace.s2),
            Expanded(
              child: _Chiffre(
                libelle: '${c.nbAchats} achat${c.nbAchats > 1 ? 's' : ''}',
                valeur: MontantTexte(c.totalAchats, devise: devise, style: theme.textTheme.titleMedium),
              ),
            ),
          ]),
          if (impayes.isNotEmpty) ...[
            const SizedBox(height: VallySpace.s6),
            const EnTeteSection('À encaisser'),
            Card(
              child: Column(children: [
                for (final (i, a) in impayes.indexed) ...[
                  if (i > 0) const Divider(),
                  ListTile(
                    onTap: () => context.push(a.estCommande ? Routes.commande(a.id) : Routes.vente(a.id)),
                    title: TexteAvecMontants([
                      'Reste ',
                      spanMontant(context, a.resteAPayer, devise, sens: SensMontant.negatif, gras: true),
                    ], style: theme.textTheme.bodyMedium, maxLines: 1),
                    subtitle: Text(
                        '${a.estCommande ? 'Commande' : 'Vente'} du ${FormatDate.court(a.date)}'),
                    trailing: FilledButton.tonal(
                      onPressed: () => _encaisser(context, ref, a),
                      style: FilledButton.styleFrom(
                          minimumSize: const Size(40, 36), visualDensity: VisualDensity.compact),
                      child: const Text('Encaisser'),
                    ),
                  ),
                ],
              ]),
            ),
          ],
          if (enCours.isNotEmpty) ...[
            const SizedBox(height: VallySpace.s6),
            const EnTeteSection('Commandes en cours',
                sousTitre: 'Pas encore des ventes : comptées une fois payées ou livrées'),
            Card(
              child: Column(children: [
                for (final (i, a) in enCours.indexed) ...[
                  if (i > 0) const Divider(),
                  ListTile(
                    onTap: () => context.push(Routes.commande(a.id)),
                    leading: const Icon(Icons.inventory_outlined),
                    title: TexteAvecMontants([
                      spanMontant(context, a.total, devise, gras: true),
                      if (a.totalPaye > 0) ...[
                        ' · avance ',
                        spanMontant(context, a.totalPaye, devise, sens: SensMontant.positif),
                      ],
                    ], style: theme.textTheme.bodyMedium, maxLines: 1),
                    subtitle: Text(a.dateLivraison == null
                        ? 'Commande du ${FormatDate.court(a.date)}'
                        : 'À livrer ${FormatDate.relatif(a.dateLivraison!).toLowerCase()}'),
                    trailing: PastilleLivraison(statut: a.statutLivraison),
                  ),
                ],
              ]),
            ),
          ],
          const SizedBox(height: VallySpace.s6),
          EnTeteSection('Historique',
              sousTitre: achats.isEmpty ? 'Aucun achat pour l’instant' : null),
          if (achats.isNotEmpty)
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(children: [
                for (final (i, a) in achats.indexed) ...[
                  if (i > 0) const Divider(),
                  ListTile(
                    onTap: () => context.push(a.estCommande ? Routes.commande(a.id) : Routes.vente(a.id)),
                    leading: Icon(a.estCommande ? Icons.inventory_outlined : Icons.point_of_sale_outlined),
                    title: Text(
                        '${a.estCommande ? 'Commande' : 'Vente'} · ${a.nbPieces} pièce${a.nbPieces > 1 ? 's' : ''}'),
                    subtitle: Text(FormatDate.court(a.date)),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        MontantTexte(a.total, devise: devise, style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 2),
                        a.estCommande && !a.annulee && a.statutPaiement == StatutPaiement.soldee
                            ? PastilleLivraison(statut: a.statutLivraison)
                            : BadgePaiement(commande: a, devise: devise),
                      ],
                    ),
                  ),
                ],
              ]),
            ),
        ],
      ),
    );
  }
}

class _Chiffre extends StatelessWidget {
  const _Chiffre({required this.libelle, required this.valeur});

  final String libelle;
  final Widget valeur;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(libelle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: valeur),
        ]),
      ),
    );
  }
}

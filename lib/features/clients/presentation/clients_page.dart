import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format/montant.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/elements.dart';
import '../../../core/widgets/montant_texte.dart';
import '../../../core/widgets/page_erreur.dart';
import '../../../core/widgets/page_vide.dart';
import '../../../theme/app_theme.dart';
import '../../boutique/data/boutique_repository.dart';
import '../data/clients_repository.dart';
import '../domain/client_resume.dart';
import 'fiche_client_dialogue.dart';

/// Clients et dettes : qui te doit combien.
class ClientsPage extends ConsumerStatefulWidget {
  const ClientsPage({super.key, this.filtreInitial = FiltreClients.tous});

  final FiltreClients filtreInitial;

  @override
  ConsumerState<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends ConsumerState<ClientsPage> {
  late FiltreClients _filtre = widget.filtreInitial;
  String _recherche = '';

  Future<void> _nouveau() async {
    final saisie = await demanderFicheClient(context);
    if (saisie == null) return;
    try {
      await ref.read(clientsRepositoryProvider).creer(nom: saisie.nom, telephone: saisie.telephone);
      ref.invalidate(clientsResumeProvider);
      if (mounted) afficherSucces(context, '${saisie.nom} ajouté à tes clients.');
    } catch (e) {
      if (mounted) afficherErreur(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vally = theme.extension<VallyColors>()!;
    final devise = ref.watch(boutiqueActiveProvider).devise;

    return Scaffold(
      appBar: AppBar(title: const Text('Clients')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nouveau client',
        onPressed: _nouveau,
        child: const Icon(Icons.person_add_alt),
      ),
      body: ref.watch(clientsResumeProvider).when(
            skipLoadingOnRefresh: true,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => PageErreur(
                erreur: e, onReessayer: () => ref.invalidate(clientsResumeProvider)),
            data: (tous) {
              if (tous.isEmpty) {
                return const PageVide(
                  icone: Icons.people_outline,
                  titre: 'Aucun client pour l’instant',
                  message: 'Tes clients s’ajoutent quand tu notes leur nom '
                      'sur une vente ou une commande.',
                );
              }
              final debiteurs = tous.where((c) => c.doit).toList();
              final totalDu = debiteurs.fold<double>(0, (s, c) => s + c.totalDu);
              final liste = filtrerClients(tous, filtre: _filtre, recherche: _recherche);
              return RefreshIndicator(
                onRefresh: () => ref.refresh(clientsResumeProvider.future),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(VallySpace.s4, 0, VallySpace.s4, 96),
                  children: [
                    Card(
                      child: ListTile(
                        leading: Icon(
                            totalDu > 0 ? Icons.timelapse : Icons.check_circle_outline,
                            color: totalDu > 0 ? vally.attention : vally.benefice),
                        title: totalDu > 0
                            ? TexteAvecMontants([
                                'On te doit ',
                                spanMontant(context, totalDu, devise, sens: SensMontant.negatif, gras: true),
                              ], style: theme.textTheme.bodyLarge)
                            : const Text('Personne ne te doit rien'),
                        subtitle: Text(totalDu > 0
                            ? '${debiteurs.length} client${debiteurs.length > 1 ? 's' : ''}'
                            : '${tous.length} client${tous.length > 1 ? 's' : ''}'),
                      ),
                    ),
                    const SizedBox(height: VallySpace.s2 + VallySpace.s1),
                    TextField(
                      onChanged: (v) => setState(() => _recherche = v),
                      decoration: const InputDecoration(
                          hintText: 'Nom ou téléphone', prefixIcon: Icon(Icons.search)),
                    ),
                    const SizedBox(height: VallySpace.s2),
                    Wrap(spacing: VallySpace.s2, children: [
                      for (final f in FiltreClients.values)
                        FiltrePastille(
                          libelle: f.libelle,
                          actif: _filtre == f,
                          compte: f == FiltreClients.meDoivent ? debiteurs.length : null,
                          alerte: true,
                          onTap: () => setState(() => _filtre = f),
                        ),
                    ]),
                    const SizedBox(height: VallySpace.s2),
                    if (liste.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(VallySpace.s6),
                        child: Text('Aucun client ne correspond.',
                            textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                      )
                    else
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(children: [
                          for (final (i, c) in liste.indexed) ...[
                            if (i > 0) const Divider(indent: 68),
                            ClientTuile(
                              client: c,
                              devise: devise,
                              onTap: () => context.push(Routes.client(c.id)),
                            ),
                          ],
                        ]),
                      ),
                  ],
                ),
              );
            },
          ),
    );
  }
}

class ClientTuile extends StatelessWidget {
  const ClientTuile({super.key, required this.client, required this.devise, this.onTap});

  final ClientResume client;
  final Devise devise;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = client;
    return ListTile(
      onTap: onTap,
      leading: AvatarInitiales(c.initiales, taille: 36),
      title: Text(c.nom, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text([
        if (c.telephone != null) c.telephone!,
        '${c.nbAchats} achat${c.nbAchats > 1 ? 's' : ''}',
      ].join(' · ')),
      trailing: c.doit
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                MontantTexte(c.totalDu,
                    devise: devise, sens: SensMontant.negatif, style: theme.textTheme.titleSmall),
                Text('doit', style: theme.textTheme.labelSmall),
              ],
            )
          : null,
    );
  }
}

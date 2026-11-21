import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format/montant.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/carnet.dart';
import '../../../core/widgets/elements.dart';
import '../../../core/widgets/montant_texte.dart';
import '../../../theme/theme_mode.dart';
import '../../auth/data/auth_repository.dart';
import '../../boutique/data/boutique_repository.dart';
import '../../clients/data/clients_repository.dart';

/// Onglet « Plus » : la boutique, les outils du quotidien (clients, chiffres,
/// dépenses, devises), l'apparence, et le compte tout en bas.
class PlusPage extends ConsumerWidget {
  const PlusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final boutique = ref.watch(boutiqueActiveProvider);
    final email = ref.watch(authRepositoryProvider).utilisateurActuel?.email;
    final clients = ref.watch(clientsResumeProvider).value ?? const [];
    final nbDebiteurs = clients.where((c) => c.doit).length;
    final totalDu = clients.fold<double>(0, (s, c) => s + c.totalDu);
    final mode = ref.watch(modeThemeProvider);
    final taux = '1 USD = ${FormatMontant.formater(boutique.tauxUsdCdf, Devise.cdf)}';

    return Scaffold(
      appBar: AppBar(title: const Text('Plus'), actions: const [BoutonTheme()]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: _Entree(
              icone: Icons.storefront_outlined,
              titre: boutique.nom,
              nomDeBoutique: true,
              sousTitre: const Text('Nom, taux de change, membres'),
              onTap: () => context.push(Routes.maBoutique),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              _Entree(
                icone: Icons.people_outline,
                titre: 'Clients et dettes',
                // Le montant suit, à droite : « 3 clients te doivent − 67 000 CDF ».
                sousTitre: Text(switch (nbDebiteurs) {
                  0 => 'Personne ne te doit d’argent',
                  1 => '1 client te doit',
                  final n => '$n clients te doivent',
                }),
                fin: totalDu > 0
                    ? MontantTexte(totalDu,
                        devise: boutique.devise,
                        sens: SensMontant.negatif,
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))
                    : null,
                onTap: () => context.push(Routes.clients),
              ),
              const TraitRegistre(retrait: _Entree.retraitTexte),
              _Entree(
                icone: Icons.bar_chart_rounded,
                titre: 'Statistiques',
                sousTitre: const Text('Ce qui se vend, ce que tu gagnes'),
                onTap: () => context.push(Routes.statistiques),
              ),
              const TraitRegistre(retrait: _Entree.retraitTexte),
              _Entree(
                icone: Icons.account_balance_wallet_outlined,
                titre: 'Mes dépenses',
                sousTitre: const Text('Ton argent à toi, séparé de la boutique'),
                onTap: () => context.push(Routes.depenses),
              ),
              const TraitRegistre(retrait: _Entree.retraitTexte),
              _Entree(
                icone: Icons.currency_exchange,
                titre: 'Calculateur de devises',
                sousTitre: Text('${_dateDuTaux(boutique.tauxMajLe)} : $taux'),
                onTap: () => context.push(Routes.calculateur),
              ),
            ]),
          ),

          const TitreSection('Apparence', taille: 16, marge: EdgeInsets.fromLTRB(2, 24, 2, 10)),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (m, libelle) in const [
              (ThemeMode.system, 'Comme le téléphone'),
              (ThemeMode.light, 'Clair'),
              (ThemeMode.dark, 'Sombre'),
            ])
              FiltrePastille(
                libelle: libelle,
                actif: mode == m,
                onTap: () => ref.read(modeThemeProvider.notifier).choisir(m),
              ),
          ]),

          // Le compte, tout en bas, sans carte.
          const SizedBox(height: 40),
          if (email != null)
            Text('Ton compte : $email',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12.5)),
          const SizedBox(height: 4),
          Center(
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: scheme.error),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Se déconnecter'),
              onPressed: () async {
                if (await confirmer(context,
                    titre: 'Se déconnecter ?',
                    message: 'Tu devras saisir ton email et ton mot de passe pour revenir.',
                    bouton: 'Se déconnecter',
                    destructif: true)) {
                  await ref.read(authRepositoryProvider).seDeconnecter();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// « Taux du jour », « Taux du 16 nov. » : on voit tout de suite s'il est à jour.
String _dateDuTaux(DateTime majLe, {DateTime? aujourdhui}) {
  final a = aujourdhui ?? DateTime.now();
  if (DateUtils.isSameDay(majLe, a)) return 'Taux du jour';
  return 'Taux du ${DateFormat(majLe.year == a.year ? 'd MMM' : 'd MMM y', 'fr').format(majLe)}';
}

/// Une entrée du menu : icône simple (sans tuile colorée), titre, phrase
/// qui dit à quoi ça sert, valeur facultative et chevron.
class _Entree extends StatelessWidget {
  const _Entree({
    required this.icone,
    required this.titre,
    this.sousTitre,
    this.fin,
    required this.onTap,
    this.nomDeBoutique = false,
  });

  /// Début du texte (16 + icône 22 + 16) : les traits s'y alignent.
  static const retraitTexte = 54.0;

  final IconData icone;
  final String titre;
  final Widget? sousTitre;
  final Widget? fin;
  final VoidCallback onTap;

  /// Le nom de la boutique s'écrit dans la police des titres.
  final bool nomDeBoutique;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
        child: Row(children: [
          Icon(icone, size: 22, color: scheme.onSurfaceVariant),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                titre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: nomDeBoutique
                    ? theme.textTheme.titleLarge?.copyWith(fontSize: 17)
                    : theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (sousTitre != null) ...[
                const SizedBox(height: 2),
                DefaultTextStyle.merge(
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 12.5),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  child: sousTitre!,
                ),
              ],
            ]),
          ),
          if (fin != null) ...[const SizedBox(width: 8), fin!],
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 20, color: scheme.onSurfaceVariant),
        ]),
      ),
    );
  }
}

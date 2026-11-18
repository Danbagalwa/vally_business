import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format/montant.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/elements.dart';
import '../../../core/widgets/montant_texte.dart';
import '../../../theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../../boutique/data/boutique_repository.dart';
import '../../clients/data/clients_repository.dart';

/// Onglet « Plus » : clients, dépenses, statistiques, boutique, compte.
class PlusPage extends ConsumerWidget {
  const PlusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final boutique = ref.watch(boutiqueActiveProvider);
    final email = ref.watch(authRepositoryProvider).utilisateurActuel?.email;
    final clients = ref.watch(clientsResumeProvider).value ?? const [];
    final totalDu = clients.fold<double>(0, (s, c) => s + c.totalDu);

    Widget entree({
      required IconData icone,
      required String titre,
      String? sousTitre,
      Widget? fin,
      required VoidCallback onTap,
    }) =>
        ListTile(
          leading: Icon(icone),
          title: Text(titre),
          subtitle: sousTitre == null ? null : Text(sousTitre),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            ?fin,
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 20),
          ]),
          onTap: onTap,
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Plus')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(VallySpace.s4, 0, VallySpace.s4, VallySpace.s6),
        children: [
          Card(
            child: ListTile(
              leading: AvatarInitiales(boutique.nom.isEmpty ? '' : boutique.nom[0].toUpperCase()),
              title: Text(boutique.nom),
              subtitle: Text(email ?? ''),
            ),
          ),
          const SizedBox(height: VallySpace.s4),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              entree(
                icone: Icons.people_outline,
                titre: 'Clients et dettes',
                fin: totalDu > 0
                    ? MontantTexte(totalDu, devise: boutique.devise, sens: SensMontant.negatif,
                        style: theme.textTheme.bodyMedium)
                    : null,
                onTap: () => context.push(Routes.clients),
              ),
              const Divider(indent: 56),
              entree(
                icone: Icons.insights_outlined,
                titre: 'Statistiques',
                sousTitre: 'Bénéfices, articles les plus vendus',
                onTap: () => context.push(Routes.statistiques),
              ),
              const Divider(indent: 56),
              entree(
                icone: Icons.account_balance_wallet_outlined,
                titre: 'Mes dépenses',
                sousTitre: 'Séparé de la boutique',
                onTap: () => context.push(Routes.depenses),
              ),
            ]),
          ),
          const SizedBox(height: VallySpace.s4),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              entree(
                icone: Icons.storefront_outlined,
                titre: 'Ma boutique',
                sousTitre: 'Taux de change, membres',
                onTap: () => context.push(Routes.maBoutique),
              ),
              const Divider(indent: 56),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Se déconnecter'),
                onTap: () => ref.read(authRepositoryProvider).seDeconnecter(),
              ),
            ]),
          ),
          const SizedBox(height: VallySpace.s4),
          Text('1 USD = ${FormatMontant.formater(boutique.tauxUsdCdf, Devise.cdf)}',
              textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

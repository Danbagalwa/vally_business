import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/boutique/data/boutique_repository.dart';
import '../router/routes.dart';

/// Menu du compte (en haut à droite) : Ma boutique, déconnexion.
class MenuCompte extends ConsumerWidget {
  const MenuCompte({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(authRepositoryProvider).utilisateurActuel?.email;
    final aUneBoutique = ref.watch(boutiqueProvider).value != null;
    return PopupMenuButton<_Action>(
      tooltip: 'Mon compte',
      icon: const Icon(Icons.account_circle_outlined),
      onSelected: (action) async {
        switch (action) {
          case _Action.boutique:
            context.push(Routes.maBoutique);
          case _Action.deconnexion:
            await ref.read(authRepositoryProvider).seDeconnecter();
        }
      },
      itemBuilder: (context) => [
        if (email != null) PopupMenuItem(enabled: false, child: Text(email)),
        if (aUneBoutique)
          const PopupMenuItem(
            value: _Action.boutique,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.storefront_outlined),
              title: Text('Ma boutique'),
            ),
          ),
        const PopupMenuItem(
          value: _Action.deconnexion,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout),
            title: Text('Se déconnecter'),
          ),
        ),
      ],
    );
  }
}

enum _Action { boutique, deconnexion }

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format/dates.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/calculateur_devises.dart';
import '../../../theme/app_theme.dart';
import '../data/boutique_repository.dart';

/// Calculateur USD ⇄ CDF au taux de la boutique.
class CalculateurPage extends ConsumerWidget {
  const CalculateurPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final boutique = ref.watch(boutiqueActiveProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Calculateur')),
      body: ListView(
        padding: const EdgeInsets.all(VallySpace.s4),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: CalculateurDevises(tauxUsdVersCdf: boutique.tauxUsdCdf),
            ),
          ),
          const SizedBox(height: VallySpace.s2),
          Row(children: [
            Expanded(
              child: Text('Taux mis à jour le ${FormatDate.court(boutique.tauxMajLe)}',
                  style: theme.textTheme.bodySmall),
            ),
            TextButton(
              onPressed: () => context.push(Routes.maBoutique),
              child: const Text('Changer le taux'),
            ),
          ]),
        ],
      ),
    );
  }
}

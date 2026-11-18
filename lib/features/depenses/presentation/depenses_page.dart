import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/page_vide.dart';

/// Onglet « Mes dépenses ». Contenu réel : module Mes dépenses (après l'étape C).
class DepensesPage extends StatelessWidget {
  const DepensesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes dépenses'),

      ),
      body: const PageVide(
        icone: Icons.account_balance_wallet_outlined,
        titre: 'Aucun mouvement pour l’instant',
        message: 'Note tes entrées et sorties d’argent, séparées de la boutique.',
      ),
    );
  }
}

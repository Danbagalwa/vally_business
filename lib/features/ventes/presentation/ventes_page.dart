import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/menu_compte.dart';
import '../../../core/widgets/page_vide.dart';

/// Onglet « Ventes ». Contenu réel : module Ventes (après l'étape C).
class VentesPage extends StatelessWidget {
  const VentesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ventes'),
        actions: const [MenuCompte()],
      ),
      body: const PageVide(
        icone: Icons.receipt_long_outlined,
        titre: 'Aucune commande pour l’instant',
        message: 'Crée une commande pour suivre tes ventes et les paiements de tes clients.',
      ),
    );
  }
}

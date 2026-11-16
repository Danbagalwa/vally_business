import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/menu_compte.dart';
import '../../../core/widgets/page_vide.dart';

/// Onglet « Stock ». Contenu réel : module Stock (après l'étape C).
class StockPage extends StatelessWidget {
  const StockPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock'),
        actions: const [MenuCompte()],
      ),
      body: const PageVide(
        icone: Icons.inventory_2_outlined,
        titre: 'Aucun article pour l’instant',
        message: 'Ajoute ton premier article pour suivre ton stock et ce que tu as investi.',
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/menu_compte.dart';
import '../../../core/widgets/page_vide.dart';

/// Onglet « Tableau de bord ». Contenu réel : module Tableau de bord (après l'étape C).
class TableauDeBordPage extends StatelessWidget {
  const TableauDeBordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord'),
        actions: const [MenuCompte()],
      ),
      body: const PageVide(
        icone: Icons.insights_outlined,
        titre: 'Pas encore de chiffres',
        message: 'Tes ventes, tes bénéfices et la valeur de ton stock s’afficheront ici.',
      ),
    );
  }
}

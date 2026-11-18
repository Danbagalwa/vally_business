import 'package:material_ui/material_ui.dart';

import '../../theme/app_theme.dart';
import '../erreurs.dart';

/// Erreur de chargement, avec un bouton pour réessayer.
class PageErreur extends StatelessWidget {
  const PageErreur({super.key, required this.erreur, required this.onReessayer});

  final Object erreur;
  final VoidCallback onReessayer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vally = theme.extension<VallyColors>()!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(VallySpace.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 40, color: vally.attention),
            const SizedBox(height: VallySpace.s4),
            Text(messageErreur(erreur),
                style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
            const SizedBox(height: VallySpace.s4),
            OutlinedButton.icon(
              onPressed: onReessayer,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Affiche une erreur en bas de l'écran.
void afficherErreur(BuildContext context, Object erreur) {
  final vally = Theme.of(context).extension<VallyColors>()!;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Row(children: [
      Icon(Icons.error_outline, color: vally.attention),
      const SizedBox(width: VallySpace.s2),
      Expanded(child: Text(messageErreur(erreur))),
    ]),
  ));
}

/// Confirme une action réussie en bas de l'écran.
void afficherSucces(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

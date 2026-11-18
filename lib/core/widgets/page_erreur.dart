import 'package:material_ui/material_ui.dart';

import '../erreurs.dart';
import 'page_vide.dart';

/// Erreur de chargement : message compréhensible et bouton « Réessayer ».
class PageErreur extends StatelessWidget {
  const PageErreur({super.key, required this.erreur, required this.onReessayer});

  final Object erreur;
  final VoidCallback onReessayer;

  @override
  Widget build(BuildContext context) {
    return PageVide(
      icone: Icons.cloud_off_outlined,
      titre: 'Chargement impossible',
      message: messageErreur(erreur),
      action: FilledButton.tonalIcon(
        onPressed: onReessayer,
        icon: const Icon(Icons.refresh),
        label: const Text('Réessayer'),
      ),
    );
  }
}

/// Message flottant en bas de l'écran ; remplace le précédent.
/// En rouge (couleur d'erreur) si [erreur].
void afficherMessage(BuildContext context, String message, {bool erreur = false}) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      backgroundColor: erreur ? scheme.error : null,
      content: Row(children: [
        if (erreur) ...[
          Icon(Icons.error_outline, color: scheme.onError, size: 20),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(message, style: erreur ? TextStyle(color: scheme.onError) : null),
        ),
      ]),
    ));
}

/// Affiche une erreur (traduite) en bas de l'écran.
void afficherErreur(BuildContext context, Object erreur) =>
    afficherMessage(context, messageErreur(erreur), erreur: true);

/// Confirme une action réussie en bas de l'écran.
void afficherSucces(BuildContext context, String message) => afficherMessage(context, message);

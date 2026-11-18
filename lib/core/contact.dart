import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../features/clients/domain/client_resume.dart';
import 'widgets/page_erreur.dart';

/// Ouvre le composeur téléphonique.
Future<void> appeler(BuildContext context, String telephone) async {
  final ok = await launchUrl(Uri(scheme: 'tel', path: telephone.replaceAll(' ', '')));
  if (!ok && context.mounted) afficherErreur(context, 'Impossible d’ouvrir le téléphone.');
}

/// Ouvre une discussion WhatsApp, avec un message pré-rempli facultatif.
Future<void> ouvrirWhatsApp(BuildContext context, String telephone, {String? message}) async {
  final numero = numeroWhatsApp(telephone);
  if (numero == null) return;
  final uri = Uri.https('wa.me', '/$numero', {'text': ?message});
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) afficherErreur(context, 'Impossible d’ouvrir WhatsApp.');
}

/// Boutons « Appeler » et « WhatsApp » côte à côte.
class BoutonsContact extends StatelessWidget {
  const BoutonsContact({super.key, required this.telephone, this.message});

  final String telephone;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton.filledTonal(
        tooltip: 'Appeler',
        icon: const Icon(Icons.call_outlined, size: 20),
        onPressed: () => appeler(context, telephone),
      ),
      const SizedBox(width: 4),
      IconButton.filledTonal(
        tooltip: 'WhatsApp',
        icon: const Icon(Icons.chat_outlined, size: 20),
        onPressed: () => ouvrirWhatsApp(context, telephone, message: message),
      ),
    ]);
  }
}

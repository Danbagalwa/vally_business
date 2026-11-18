import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../boutique/domain/boutique.dart';
import '../../clients/domain/client_resume.dart';
import '../../ventes/domain/commande.dart';
import '../domain/facture.dart';
import 'facture_pdf.dart';

enum ResultatEnvoi {
  /// WhatsApp ouvert directement sur la discussion du client.
  whatsApp,

  /// Menu de partage du téléphone (iPhone, ou WhatsApp absent).
  partage,
}

/// Envoi de la facture : PDF généré sur le téléphone, puis
/// • Android : WhatsApp ouvert dans la discussion du client, PDF joint et
///   message pré-rempli (il reste à toucher « Envoyer ») ;
/// • sinon : menu de partage avec le PDF et le message.
class EnvoiFacture {
  static const _canal = MethodChannel('vally/whatsapp');

  /// Écrit le PDF dans le cache de l'appli (dossier « factures »).
  static Future<File> preparer(CommandeDetail detail, Boutique boutique) async {
    final octets = await genererFacturePdf(detail: detail, boutique: boutique);
    final cache = await getTemporaryDirectory();
    final dossier = Directory('${cache.path}/factures');
    if (!dossier.existsSync()) dossier.createSync(recursive: true);
    final fichier = File('${dossier.path}/${nomFichierFacture(detail.commande)}');
    await fichier.writeAsBytes(octets, flush: true);
    return fichier;
  }

  static Future<ResultatEnvoi> envoyer(
    CommandeDetail detail,
    Boutique boutique, {
    bool versWhatsApp = true,
  }) async {
    final c = detail.commande;
    final fichier = await preparer(detail, boutique);
    final message = messageRemerciement(c, boutique: boutique.nom, devise: boutique.devise);

    if (versWhatsApp && Platform.isAndroid) {
      try {
        final ok = await _canal.invokeMethod<bool>('partagerFichier', {
          'chemin': fichier.path,
          'numero': numeroWhatsApp(c.clientTelephone),
          'texte': message,
        });
        if (ok == true) return ResultatEnvoi.whatsApp;
      } on PlatformException {
        // WhatsApp absent ou refus : on passe au menu de partage.
      } on MissingPluginException {
        // Canal indisponible (tests) : idem.
      }
    }

    await SharePlus.instance.share(ShareParams(
      files: [XFile(fichier.path, mimeType: 'application/pdf', name: nomFichierFacture(c))],
      text: message,
      subject: 'Facture ${c.numero ?? ''} · ${boutique.nom}',
    ));
    return ResultatEnvoi.partage;
  }
}

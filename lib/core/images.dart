import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Photo prête à être envoyée dans Supabase Storage.
class PhotoCompressee {
  const PhotoCompressee(this.octets, this.typeMime, this.extension);

  final Uint8List octets;
  final String typeMime;
  final String extension;
}

/// Compresse une photo d'article : WebP, environ 1 080 px de côté,
/// qualité 75 (souvent 60 à 150 Ko, PNG compris). L'orientation est
/// corrigée et les métadonnées (position GPS…) retirées.
/// Si la compression échoue sur un téléphone, la photo d'origine est
/// envoyée telle quelle : l'enregistrement n'est jamais bloqué.
Future<PhotoCompressee> compresserPhoto(Uint8List original) async {
  try {
    final webp = await FlutterImageCompress.compressWithList(
      original,
      minWidth: 1080,
      minHeight: 1080,
      quality: 75,
      format: CompressFormat.webp,
    );
    if (webp.isNotEmpty && webp.length < original.length) {
      return PhotoCompressee(webp, 'image/webp', 'webp');
    }
  } catch (e) {
    debugPrint('Compression de la photo impossible : $e');
  }
  return PhotoCompressee(original, 'image/jpeg', 'jpg');
}

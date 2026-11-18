import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/erreurs.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../boutique/data/boutique_repository.dart';
import '../domain/article.dart';

const _bucketPhotos = 'photos-articles';

/// Accès aux articles (table articles, vue v_stock) et à leurs photos.
class StockRepository {
  StockRepository(this._client);

  final SupabaseClient _client;

  Future<List<Article>> lister() async {
    final lignes = await _client.from('v_stock').select().order('nom');
    return lignes.map(Article.fromJson).toList();
  }

  /// Crée l'article et retourne son id.
  Future<String> ajouter(ArticleSaisie saisie) async {
    final ligne = await _client
        .from('articles')
        .insert(saisie.toJson())
        .select('id')
        .single();
    return ligne['id'] as String;
  }

  Future<void> modifier(String id, ArticleSaisie saisie) async {
    await _client.from('articles').update(saisie.toJson()).eq('id', id);
  }

  Future<void> supprimer(Article article) async {
    try {
      await _client.from('articles').delete().eq('id', article.id);
    } on PostgrestException catch (e) {
      if (e.code == '23503') {
        throw const ErreurMetier(
            'Cet article a déjà été vendu : tu ne peux pas le supprimer.');
      }
      rethrow;
    }
    if (article.photoChemin != null) {
      await _supprimerFichier(article.photoChemin!);
    }
  }

  /// Envoie la photo dans le dossier de la boutique et la relie à l'article.
  /// Un nom unique par envoi évite qu'une ancienne image reste en cache.
  Future<void> remplacerPhoto({
    required String boutiqueId,
    required String articleId,
    required Uint8List octets,
    String? ancienChemin,
  }) async {
    final chemin =
        '$boutiqueId/$articleId-${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _client.storage.from(_bucketPhotos).uploadBinary(
          chemin,
          octets,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    await _client
        .from('articles')
        .update({'photo_url': chemin}).eq('id', articleId);
    if (ancienChemin != null) await _supprimerFichier(ancienChemin);
  }

  Future<void> retirerPhoto(String articleId, String chemin) async {
    await _client.from('articles').update({'photo_url': null}).eq('id', articleId);
    await _supprimerFichier(chemin);
  }

  /// URL temporaire (1 h) pour afficher une photo du bucket privé.
  Future<String> urlPhoto(String chemin) =>
      _client.storage.from(_bucketPhotos).createSignedUrl(chemin, 3600);

  Future<void> _supprimerFichier(String chemin) async {
    try {
      await _client.storage.from(_bucketPhotos).remove([chemin]);
    } catch (_) {
      // Un fichier orphelin n'est pas bloquant.
    }
  }
}

final stockRepositoryProvider = Provider<StockRepository>(
  (ref) => StockRepository(ref.watch(supabaseClientProvider)),
);

/// Tous les articles de la boutique, triés par nom.
final articlesProvider = FutureProvider<List<Article>>((ref) async {
  final boutique = await ref.watch(boutiqueProvider.future);
  if (boutique == null) return const [];
  return ref.watch(stockRepositoryProvider).lister();
});

/// URL signée d'une photo (mise en cache le temps de l'affichage).
final urlPhotoProvider = FutureProvider.autoDispose.family<String, String>(
  (ref, chemin) => ref.watch(stockRepositoryProvider).urlPhoto(chemin),
);

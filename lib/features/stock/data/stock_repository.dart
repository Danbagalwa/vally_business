import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/erreurs.dart';
import '../../../core/format/dates.dart';
import '../../../core/format/montant.dart';
import '../../../core/images.dart';
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
    required PhotoCompressee photo,
    String? ancienChemin,
  }) async {
    final chemin = '$boutiqueId/$articleId-'
        '${DateTime.now().millisecondsSinceEpoch}.${photo.extension}';
    await _client.storage.from(_bucketPhotos).uploadBinary(
          chemin,
          photo.octets,
          fileOptions: FileOptions(contentType: photo.typeMime),
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

  /// Racheter : ajoute des pièces et recalcule le coût moyen (par la base,
  /// qui convertit le prix saisi en USD ou en CDF). Retourne ce coût moyen.
  Future<double> reapprovisionner({
    required String articleId,
    required int quantite,
    required double prixSaisi,
    required Devise devise,
    required DateTime date,
    String? fournisseur,
  }) async {
    final cout = await _client.rpc('reapprovisionner', params: {
      'p_article': articleId,
      'p_quantite': quantite,
      'p_prix_saisi': prixSaisi,
      'p_devise_saisie': devise.code,
      'p_date': FormatDate.iso(date),
      'p_fournisseur': (fournisseur == null || fournisseur.trim().isEmpty) ? null : fournisseur.trim(),
    });
    return (cout as num).toDouble();
  }

  /// Retire le dernier rachat (erreur de saisie) : quantité et coût moyen
  /// reviennent à ce qu'ils étaient.
  Future<void> annulerDernierRachat(String articleId) async {
    await _client.rpc('annuler_dernier_rachat', params: {'p_article': articleId});
  }

  /// Les achats d'un article, le plus récent d'abord.
  Future<List<Achat>> achats(String articleId) async {
    final lignes = await _client
        .from('approvisionnements')
        .select()
        .eq('article_id', articleId)
        .order('created_at', ascending: false);
    return lignes.map(Achat.fromJson).toList();
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

/// Historique des achats d'un article (rechargé quand les articles changent).
final achatsArticleProvider = FutureProvider.autoDispose.family<List<Achat>, String>((ref, articleId) async {
  await ref.watch(articlesProvider.future);
  return ref.watch(stockRepositoryProvider).achats(articleId);
});

/// URL signée d'une photo (mise en cache le temps de l'affichage).
final urlPhotoProvider = FutureProvider.autoDispose.family<String, String>(
  (ref, chemin) => ref.watch(stockRepositoryProvider).urlPhoto(chemin),
);

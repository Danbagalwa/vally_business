import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/format/montant.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/boutique.dart';

/// Accès à la boutique du compte connecté et à ses membres.
class BoutiqueRepository {
  BoutiqueRepository(this._client);

  final SupabaseClient _client;

  /// La boutique du compte (RLS ne renvoie que la sienne), ou null.
  Future<Boutique?> maBoutique() async {
    final ligne = await _client.from('boutiques').select().maybeSingle();
    return ligne == null ? null : Boutique.fromJson(ligne);
  }

  Future<void> creer({
    required String nom,
    required Devise devise,
    required double tauxUsdCdf,
  }) async {
    await _client.rpc('creer_boutique', params: {
      'p_nom': nom,
      'p_devise_reference': devise.code,
      'p_taux_usd_cdf': tauxUsdCdf,
    });
  }

  Future<void> modifier(String id, {String? nom, double? tauxUsdCdf}) async {
    await _client.from('boutiques').update({
      'nom': ?nom,
      'taux_usd_cdf': ?tauxUsdCdf,
    }).eq('id', id);
  }

  Future<List<Membre>> membres() async {
    final lignes = await _client.rpc('membres_boutique') as List<dynamic>;
    return lignes
        .map((l) => Membre.fromJson(l as Map<String, dynamic>))
        .toList();
  }

  Future<void> ajouterMembre(String email) async {
    await _client.rpc('ajouter_membre', params: {'p_email': email.trim()});
  }

  Future<void> retirerMembre(String userId) async {
    await _client.rpc('retirer_membre', params: {'p_user_id': userId});
  }
}

final boutiqueRepositoryProvider = Provider<BoutiqueRepository>(
  (ref) => BoutiqueRepository(ref.watch(supabaseClientProvider)),
);

/// Boutique du compte connecté (null : pas encore de boutique).
/// Se recharge à chaque changement de compte.
final boutiqueProvider = FutureProvider<Boutique?>((ref) async {
  final userId = await ref.watch(utilisateurIdProvider.future);
  if (userId == null) return null;
  return ref.watch(boutiqueRepositoryProvider).maBoutique();
});

/// Boutique active, pour les écrans affichés derrière la PorteBoutique
/// (qui garantit qu'elle existe).
final boutiqueActiveProvider = Provider<Boutique>(
  (ref) => ref.watch(boutiqueProvider).requireValue!,
);

final membresProvider = FutureProvider.autoDispose<List<Membre>>(
  (ref) => ref.watch(boutiqueRepositoryProvider).membres(),
);

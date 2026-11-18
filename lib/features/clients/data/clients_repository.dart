import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../boutique/data/boutique_repository.dart';
import '../../ventes/data/ventes_repository.dart';
import '../domain/client_resume.dart';

/// Clients de la boutique (table clients, vue v_clients).
class ClientsRepository {
  ClientsRepository(this._client);

  final SupabaseClient _client;

  Future<List<ClientResume>> lister() async {
    final lignes = await _client.from('v_clients').select().order('nom');
    return lignes.map(ClientResume.fromJson).toList();
  }

  Future<void> creer({required String nom, String? telephone}) async {
    await _client.from('clients').insert({
      'nom': nom.trim(),
      'telephone': _videEnNull(telephone),
    });
  }

  Future<void> modifier(String id, {required String nom, String? telephone}) async {
    await _client.from('clients').update({
      'nom': nom.trim(),
      'telephone': _videEnNull(telephone),
    }).eq('id', id);
  }

  /// Ses ventes et commandes restent, sans client.
  Future<void> supprimer(String id) async {
    await _client.from('clients').delete().eq('id', id);
  }

  static String? _videEnNull(String? t) {
    final v = t?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }
}

final clientsRepositoryProvider = Provider<ClientsRepository>(
  (ref) => ClientsRepository(ref.watch(supabaseClientProvider)),
);

/// Clients avec achats et dettes. Se recharge après chaque vente,
/// commande ou paiement (commandesProvider est alors invalidé).
final clientsResumeProvider = FutureProvider<List<ClientResume>>((ref) async {
  final boutique = await ref.watch(boutiqueProvider.future);
  if (boutique == null) return const [];
  await ref.watch(commandesProvider.future);
  return ref.watch(clientsRepositoryProvider).lister();
});

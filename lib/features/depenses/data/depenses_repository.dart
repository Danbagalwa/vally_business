import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/format/dates.dart';
import '../../../core/format/montant.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../boutique/data/boutique_repository.dart';
import '../domain/mouvement.dart';

/// Mes dépenses : table mouvements, vue v_flux_mensuel, versement de bénéfice.
class DepensesRepository {
  DepensesRepository(this._client);

  final SupabaseClient _client;

  Future<List<Mouvement>> lister() async {
    final lignes = await _client
        .from('mouvements')
        .select()
        .order('date_mouvement', ascending: false)
        .order('created_at', ascending: false);
    return lignes.map(Mouvement.fromJson).toList();
  }

  Future<List<FluxMensuel>> fluxMensuel() async {
    final lignes = await _client.from('v_flux_mensuel').select().order('mois', ascending: false).limit(12);
    return lignes.map(FluxMensuel.fromJson).toList();
  }

  Future<void> ajouter(MouvementSaisie saisie) async {
    await _client.from('mouvements').insert(saisie.toJson());
  }

  Future<void> modifier(String id, MouvementSaisie saisie) async {
    await _client.from('mouvements').update(saisie.toJson()).eq('id', id);
  }

  /// Supprimer un versement de bénéfice le rend de nouveau disponible.
  Future<void> supprimer(String id) async {
    await _client.from('mouvements').delete().eq('id', id);
  }

  /// « Me verser un bénéfice » : plafonné par la base au bénéfice encaissé.
  Future<void> verserBenefice({
    required double montantSaisi,
    required Devise devise,
    required DateTime date,
    String? note,
  }) async {
    await _client.rpc('verser_benefice', params: {
      'p_montant_saisi': montantSaisi,
      'p_devise_saisie': devise.code,
      'p_date': FormatDate.iso(date),
      'p_note': (note == null || note.trim().isEmpty) ? null : note.trim(),
    });
  }
}

final depensesRepositoryProvider = Provider<DepensesRepository>(
  (ref) => DepensesRepository(ref.watch(supabaseClientProvider)),
);

final mouvementsProvider = FutureProvider<List<Mouvement>>((ref) async {
  final boutique = await ref.watch(boutiqueProvider.future);
  if (boutique == null) return const [];
  return ref.watch(depensesRepositoryProvider).lister();
});

/// 12 derniers mois, recalculés quand les mouvements changent.
final fluxMensuelProvider = FutureProvider.autoDispose<List<FluxMensuel>>((ref) async {
  await ref.watch(mouvementsProvider.future);
  return ref.watch(depensesRepositoryProvider).fluxMensuel();
});

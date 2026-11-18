import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/format/dates.dart';
import '../../../core/format/montant.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../boutique/data/boutique_repository.dart';
import '../domain/commande.dart';
import '../domain/panier.dart';

/// Accès aux commandes, lignes, paiements et clients.
class VentesRepository {
  VentesRepository(this._client);

  final SupabaseClient _client;

  Future<List<Commande>> lister() async {
    final lignes = await _client
        .from('v_commandes')
        .select()
        .order('date_commande', ascending: false)
        .order('created_at', ascending: false);
    return lignes.map(Commande.fromJson).toList();
  }

  Future<CommandeDetail> detail(String id) async {
    final resultats = await Future.wait([
      _client.from('v_commandes').select().eq('id', id).single(),
      _client
          .from('lignes_commande')
          .select('*, articles(nom, categorie, taille, couleur)')
          .eq('commande_id', id)
          .order('created_at'),
      _client
          .from('paiements')
          .select()
          .eq('commande_id', id)
          .order('date_paiement')
          .order('created_at'),
    ]);
    return CommandeDetail(
      commande: Commande.fromJson(resultats[0] as Map<String, dynamic>),
      lignes: (resultats[1] as List)
          .map((l) => LigneCommande.fromJson(l as Map<String, dynamic>))
          .toList(),
      paiements: (resultats[2] as List)
          .map((p) => Paiement.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<List<Client>> clients() async {
    final lignes = await _client.from('clients').select().order('nom');
    return lignes.map(Client.fromJson).toList();
  }

  /// Crée client (si nouveau), commande, lignes et premier paiement en une
  /// transaction (fonction SQL creer_commande). Retourne l'id de la commande.
  Future<String> creer({
    required List<LignePanier> lignes,
    String? clientId,
    String? clientNom,
    String? clientTelephone,
    required DateTime date,
    String? note,
    PaiementSaisi? paiement,
  }) async {
    final id = await _client.rpc('creer_commande', params: {
      'p_lignes': lignes.map((l) => l.toJson()).toList(),
      'p_client_id': clientId,
      'p_client_nom': clientId == null ? clientNom : null,
      'p_client_telephone': clientId == null ? clientTelephone : null,
      'p_date': FormatDate.iso(date),
      'p_note': note,
      'p_paiement': paiement?.toJson(),
    });
    return id as String;
  }

  Future<void> ajouterPaiement(String commandeId, PaiementSaisi paiement) async {
    await _client.from('paiements').insert({
      'commande_id': commandeId,
      ...paiement.toJson(),
      'date_paiement': FormatDate.iso(paiement.date),
    });
  }

  Future<void> supprimerPaiement(String id) async {
    await _client.from('paiements').delete().eq('id', id);
  }

  Future<void> changerStatutLivraison(
      String commandeId, StatutLivraison statut) async {
    await _client
        .from('commandes')
        .update({'statut_livraison': statut.code}).eq('id', commandeId);
  }

  Future<void> supprimer(String commandeId) async {
    await _client.from('commandes').delete().eq('id', commandeId);
  }
}

/// Paiement tel que saisi : la base le convertit dans la devise de référence.
class PaiementSaisi {
  const PaiementSaisi({
    required this.montantSaisi,
    required this.devise,
    required this.mode,
    required this.date,
  });

  final double montantSaisi;
  final Devise devise;
  final ModePaiement mode;
  final DateTime date;

  Map<String, dynamic> toJson() => {
        'montant_saisi': montantSaisi,
        'devise_saisie': devise.code,
        'mode': mode.code,
      };
}

final ventesRepositoryProvider = Provider<VentesRepository>(
  (ref) => VentesRepository(ref.watch(supabaseClientProvider)),
);

/// Toutes les commandes, les plus récentes d'abord.
final commandesProvider = FutureProvider<List<Commande>>((ref) async {
  final boutique = await ref.watch(boutiqueProvider.future);
  if (boutique == null) return const [];
  return ref.watch(ventesRepositoryProvider).lister();
});

final commandeDetailProvider =
    FutureProvider.autoDispose.family<CommandeDetail, String>(
  (ref, id) => ref.watch(ventesRepositoryProvider).detail(id),
);

final clientsProvider = FutureProvider.autoDispose<List<Client>>(
  (ref) => ref.watch(ventesRepositoryProvider).clients(),
);

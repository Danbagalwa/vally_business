import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../domain/erreur_auth.dart';

/// Accès à Supabase Auth (email + mot de passe).
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  User? get utilisateurActuel => _auth.currentUser;
  bool get estConnecte => _auth.currentSession != null;

  Stream<AuthState> get changements => _auth.onAuthStateChange;

  Future<void> seConnecter({
    required String email,
    required String motDePasse,
  }) =>
      _traduire(() => _auth.signInWithPassword(
            email: email.trim(),
            password: motDePasse,
          ));

  /// Retourne `true` si le compte est utilisable tout de suite, `false` si
  /// Supabase attend la confirmation de l'adresse email.
  Future<bool> creerCompte({
    required String email,
    required String motDePasse,
  }) async {
    final reponse = await _traduire(() => _auth.signUp(
          email: email.trim(),
          password: motDePasse,
        ));
    return reponse.session != null;
  }

  Future<void> seDeconnecter() => _auth.signOut();

  Future<T> _traduire<T>(Future<T> Function() appel) async {
    try {
      return await appel();
    } on AuthException catch (e) {
      throw ErreurAuth.depuisSupabase(e.code, e.message);
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);

/// Identifiant du compte connecté (null si déconnecté). Change à chaque
/// connexion / déconnexion : les données dépendantes se rechargent.
final utilisateurIdProvider = StreamProvider<String?>((ref) async* {
  final auth = ref.watch(authRepositoryProvider);
  yield auth.utilisateurActuel?.id;
  yield* auth.changements.map((etat) => etat.session?.user.id).distinct();
});

/// Erreur d'authentification avec un message prêt à afficher (en français).
class ErreurAuth implements Exception {
  const ErreurAuth(this.message);

  final String message;

  factory ErreurAuth.depuisSupabase(String? code, String messageBrut) {
    final message = switch (code) {
      'invalid_credentials' => 'Email ou mot de passe incorrect.',
      'email_not_confirmed' =>
        'Confirme d’abord ton adresse email avec le lien reçu.',
      'user_already_exists' ||
      'email_exists' =>
        'Un compte existe déjà avec cet email. Connecte-toi.',
      'weak_password' =>
        'Mot de passe trop faible : au moins 8 caractères.',
      'over_email_send_rate_limit' || 'over_request_rate_limit' =>
        'Trop de tentatives. Réessaie dans quelques minutes.',
      'validation_failed' => 'Vérifie l’adresse email.',
      _ => 'Connexion impossible. Vérifie ta connexion internet et réessaie.',
    };
    return ErreurAuth(message);
  }

  @override
  String toString() => message;
}

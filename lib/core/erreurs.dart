import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Erreur métier avec un message prêt à afficher.
class ErreurMetier implements Exception {
  const ErreurMetier(this.message);

  final String message;

  @override
  String toString() => message;
}

const _messageReseau =
    'Pas de connexion internet. Vérifie ton réseau et réessaie.';

/// Transforme n'importe quelle erreur en phrase courte, en français.
String messageErreur(Object erreur) {
  if (erreur is ErreurMetier) return erreur.message;
  if (erreur is PostgrestException) {
    // Erreurs levées par nos règles SQL : le message est déjà rédigé.
    if (erreur.code == 'P0001') return erreur.message;
    return switch (erreur.code) {
      '23503' => 'Impossible : cet élément est utilisé ailleurs.',
      '23505' => 'Cet élément existe déjà.',
      '23514' || '23502' => 'Une valeur saisie n’est pas valide.',
      '42501' => 'Tu n’as pas accès à cette donnée.',
      _ => 'Une erreur est survenue. Réessaie dans un instant.',
    };
  }
  if (erreur is StorageException) {
    return 'La photo n’a pas pu être envoyée. Réessaie.';
  }
  if (erreur is SocketException || erreur is TimeoutException) {
    return _messageReseau;
  }
  final texte = erreur.toString();
  if (texte.contains('SocketException') ||
      texte.contains('ClientException') ||
      texte.contains('Failed host lookup')) {
    return _messageReseau;
  }
  return 'Une erreur est survenue. Réessaie dans un instant.';
}

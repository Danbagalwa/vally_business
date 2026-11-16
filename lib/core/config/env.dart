/// Configuration injectée au lancement par `--dart-define` ou
/// `--dart-define-from-file=dart_defines.json`. Aucune clé n'est écrite
/// dans le code source.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get estConfigure =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}

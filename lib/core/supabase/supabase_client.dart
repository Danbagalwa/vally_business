import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

/// Initialise Supabase une seule fois au démarrage.
Future<void> initialiserSupabase() async {
  await Supabase.initialize(
    url: Env.supabaseUrl,
    // Accepte la clé publique « sb_publishable_… » (ou l'ancienne clé anon).
    publishableKey: Env.supabaseAnonKey,
  );
}

/// Client Supabase, injecté partout via Riverpod (remplaçable dans les tests).
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

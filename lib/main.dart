import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/supabase/supabase_client.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // Garde l'écran de démarrage natif pendant l'initialisation.
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  Intl.defaultLocale = 'fr';
  await initializeDateFormatting('fr');

  if (!Env.estConfigure) {
    runApp(const ConfigurationManquanteApp());
    FlutterNativeSplash.remove();
    return;
  }

  await initialiserSupabase();
  runApp(const ProviderScope(child: VallyApp()));
  FlutterNativeSplash.remove();
}

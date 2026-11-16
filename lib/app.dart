import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/router/app_router.dart';
import 'theme/app_theme.dart';

/// Racine de l'application.
class VallyApp extends ConsumerWidget {
  const VallyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Vally Business',
      debugShowCheckedModeBanner: false,
      theme: VallyTheme.light,
      darkTheme: VallyTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(routerProvider),
    );
  }
}

/// Affichée si l'appli est lancée sans les clés Supabase.
class ConfigurationManquanteApp extends StatelessWidget {
  const ConfigurationManquanteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vally Business',
      debugShowCheckedModeBanner: false,
      theme: VallyTheme.light,
      darkTheme: VallyTheme.dark,
      themeMode: ThemeMode.system,
      home: Builder(builder: (context) {
        final theme = Theme.of(context);
        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(VallySpace.s6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Configuration manquante',
                      style: theme.textTheme.headlineSmall),
                  const SizedBox(height: VallySpace.s4),
                  Text(
                    'Lance l’appli avec tes clés Supabase :',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: VallySpace.s2),
                  SelectableText(
                    'flutter run --dart-define-from-file=dart_defines.json',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

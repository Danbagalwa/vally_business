import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:material_ui/material_ui.dart';

import 'theme/app_theme.dart';

void main() {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // Garde l'écran de démarrage natif jusqu'à ce que l'appli soit prête.
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  runApp(const VallyApp());
  FlutterNativeSplash.remove();
}

class VallyApp extends StatelessWidget {
  const VallyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vally Business',
      debugShowCheckedModeBanner: false,
      theme: VallyTheme.light,
      darkTheme: VallyTheme.dark,
      themeMode: ThemeMode.system,
      home: const _AccueilTemporaire(),
    );
  }
}

/// Écran provisoire pour vérifier le thème (remplacé à l'étape B).
class _AccueilTemporaire extends StatelessWidget {
  const _AccueilTemporaire();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vally = theme.extension<VallyColors>()!;
    return Scaffold(
      appBar: AppBar(title: const Text('Vally Business')),
      body: ListView(
        padding: const EdgeInsets.all(VallySpace.s4),
        children: [
          Text('Ton stock, tes ventes et ton argent, au même endroit.',
              style: theme.textTheme.bodyLarge),
          const SizedBox(height: VallySpace.s6),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(VallySpace.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bénéfice', style: theme.textTheme.labelLarge),
                  const SizedBox(height: VallySpace.s2),
                  Text('+ 125 000 CDF',
                      style: theme.textTheme.displaySmall
                          ?.copyWith(color: vally.benefice)),
                  const SizedBox(height: VallySpace.s4),
                  Text('Reste à payer', style: theme.textTheme.labelLarge),
                  const SizedBox(height: VallySpace.s2),
                  Text('− 40 000 CDF',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(color: vally.attention)),
                ],
              ),
            ),
          ),
          const SizedBox(height: VallySpace.s6),
          FilledButton(onPressed: () {}, child: const Text('Ajouter un article')),
        ],
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';

import '../../theme/app_theme.dart';

/// État vide d'un écran : icône, titre et phrase d'aide.
class PageVide extends StatelessWidget {
  const PageVide({
    super.key,
    required this.icone,
    required this.titre,
    required this.message,
  });

  final IconData icone;
  final String titre;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(VallySpace.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundColor: theme.colorScheme.onPrimaryContainer,
              child: Icon(icone, size: 32),
            ),
            const SizedBox(height: VallySpace.s4),
            Text(titre,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: VallySpace.s2),
            Text(message,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';

import '../../theme/app_theme.dart';

/// État vide : icône 56 px, titre, phrase qui dit quoi faire, action facultative.
class PageVide extends StatelessWidget {
  const PageVide({
    super.key,
    required this.icone,
    required this.titre,
    required this.message,
    this.action,
  });

  final IconData icone;
  final String titre;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: VallySpace.s6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(child: Icon(icone, size: 56, color: theme.colorScheme.outline)),
              const SizedBox(height: VallySpace.s4),
              Text(titre, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: VallySpace.s2),
              Text(message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant, height: 1.4),
                  textAlign: TextAlign.center),
              if (action != null) ...[const SizedBox(height: VallySpace.s4), action!],
            ],
          ),
        ),
      ),
    );
  }
}

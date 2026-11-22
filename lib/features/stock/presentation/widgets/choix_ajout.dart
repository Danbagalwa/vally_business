import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Les deux façons de remplir le stock, bien séparées.
enum ChoixAjout { nouvelArticle, reapprovisionner }

/// « + » du stock : nouvel article, ou rachat d'un article qu'on a déjà.
Future<ChoixAjout?> choisirAjout(BuildContext context) => showModalBottomSheet<ChoixAjout>(
      context: context,
      builder: (context) => const _FeuilleChoix(),
    );

class _FeuilleChoix extends StatelessWidget {
  const _FeuilleChoix();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Ajouter au stock', style: theme.textTheme.titleLarge),
          const SizedBox(height: 14),
          const _Choix(
            choix: ChoixAjout.nouvelArticle,
            icone: Icons.checkroom_outlined,
            titre: 'Nouvel article',
            texte: 'Un vêtement que tu n’as encore jamais eu en boutique.',
          ),
          const SizedBox(height: 10),
          const _Choix(
            choix: ChoixAjout.reapprovisionner,
            icone: Icons.inventory_2_outlined,
            titre: 'Réapprovisionner',
            texte: 'Tu as racheté des pièces d’un article que tu as déjà.',
          ),
        ]),
      ),
    );
  }
}

class _Choix extends StatelessWidget {
  const _Choix({required this.choix, required this.icone, required this.titre, required this.texte});

  final ChoixAjout choix;
  final IconData icone;
  final String titre;
  final String texte;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final forme = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: scheme.outlineVariant),
    );
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: forme,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.pop(context, choix);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(children: [
            Icon(icone, size: 26, color: scheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(titre, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text(texte, style: theme.textTheme.bodySmall?.copyWith(fontSize: 12.5, height: 1.3)),
              ]),
            ),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ]),
        ),
      ),
    );
  }
}

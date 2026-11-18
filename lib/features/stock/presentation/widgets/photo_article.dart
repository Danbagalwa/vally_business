import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../theme/app_theme.dart';
import '../../data/stock_repository.dart';

/// Vignette de la photo d'un article (ou icône par défaut).
class PhotoArticle extends ConsumerWidget {
  const PhotoArticle({super.key, required this.chemin, this.taille = 56});

  final String? chemin;
  final double taille;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final defaut = ColoredBox(
      color: theme.colorScheme.primaryContainer,
      child: Center(
        child: Icon(Icons.checkroom_outlined,
            size: taille * 0.45, color: theme.colorScheme.onPrimaryContainer),
      ),
    );

    Widget contenu = defaut;
    if (chemin != null) {
      contenu = ref.watch(urlPhotoProvider(chemin!)).when(
            data: (url) => Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => defaut,
            ),
            loading: () => defaut,
            error: (_, _) => defaut,
          );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(VallyRadius.sm),
      child: SizedBox.square(dimension: taille, child: contenu),
    );
  }
}

import 'package:material_ui/material_ui.dart';

import '../../theme/app_theme.dart';

/// Barre fixée en bas de l'écran pour l'action principale
/// (bouton pleine largeur, toujours visible au-dessus du clavier).
class BarreAction extends StatelessWidget {
  const BarreAction({
    super.key,
    required this.libelle,
    required this.onPressed,
    this.enCours = false,
    this.icone,
    this.resume,
  });

  final String libelle;
  final VoidCallback? onPressed;
  final bool enCours;
  final IconData? icone;

  /// Affiché à gauche du bouton (ex. : le total).
  final Widget? resume;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bouton = FilledButton.icon(
      onPressed: enCours ? null : onPressed,
      style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
      icon: enCours
          ? const SizedBox.square(
              dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : (icone == null ? const SizedBox.shrink() : Icon(icone, size: 20)),
      label: Text(libelle),
    );
    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
          ),
          padding: const EdgeInsets.fromLTRB(
              VallySpace.s4, VallySpace.s2 + VallySpace.s1, VallySpace.s4, VallySpace.s2 + VallySpace.s1),
          child: resume == null
              ? SizedBox(width: double.infinity, child: bouton)
              : Row(children: [
                  Expanded(child: resume!),
                  const SizedBox(width: VallySpace.s4),
                  bouton,
                ]),
        ),
      ),
    );
  }
}

/// Titre de section avec action facultative à droite (« Voir tout »).
class EnTeteSection extends StatelessWidget {
  const EnTeteSection(this.titre, {super.key, this.sousTitre, this.action, this.onAction});

  final String titre;
  final String? sousTitre;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: VallySpace.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titre, style: theme.textTheme.titleMedium),
                if (sousTitre != null)
                  Text(sousTitre!, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                  minimumSize: const Size(40, 32),
                  visualDensity: VisualDensity.compact),
              child: Text(action!),
            ),
        ],
      ),
    );
  }
}

/// Petite pastille d'état : icône + texte.
class Pastille extends StatelessWidget {
  const Pastille({
    super.key,
    required this.texte,
    this.icone,
    this.couleur,
    this.fond,
  });

  final String texte;
  final IconData? icone;

  /// Couleur du texte et de l'icône (par défaut : texte secondaire).
  final Color? couleur;
  final Color? fond;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = couleur ?? theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: fond ?? c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(VallyRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[
            Icon(icone, size: 13, color: c),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(texte,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: c, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// Rangée de filtres (pastilles) défilant horizontalement.
class RangeeFiltres extends StatelessWidget {
  const RangeeFiltres({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: VallySpace.s4),
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(width: VallySpace.s2),
        itemBuilder: (_, i) => Center(child: children[i]),
      ),
    );
  }
}

/// Pastille de filtre avec compteur facultatif : « Aujourd'hui 3 ».
class FiltrePastille extends StatelessWidget {
  const FiltrePastille({
    super.key,
    required this.libelle,
    required this.actif,
    required this.onTap,
    this.compte,
    this.alerte = false,
    this.icone,
  });

  final String libelle;
  final bool actif;
  final VoidCallback onTap;
  final int? compte;

  /// Compteur en couleur « attention » (ex. : commandes en retard).
  final bool alerte;
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vally = theme.extension<VallyColors>()!;
    return FilterChip(
      selected: actif,
      onSelected: (_) => onTap(),
      visualDensity: VisualDensity.compact,
      avatar: icone == null ? null : Icon(icone, size: 16),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(libelle),
          if (compte != null && compte! > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: alerte ? vally.attention : theme.colorScheme.onPrimaryContainer,
                borderRadius: BorderRadius.circular(VallyRadius.pill),
              ),
              child: Text('$compte',
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.surfaceContainer,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }
}

/// En-tête de groupe dans une liste (« Aujourd'hui · 3 ventes »).
class EnTeteGroupe extends StatelessWidget {
  const EnTeteGroupe({super.key, required this.titre, this.detail, this.alerte = false});

  final String titre;
  final Widget? detail;
  final bool alerte;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vally = theme.extension<VallyColors>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, VallySpace.s4, 4, VallySpace.s2),
      child: Row(children: [
        if (alerte) ...[
          Icon(Icons.warning_amber_rounded, size: 16, color: vally.attention),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Text(titre,
              style: theme.textTheme.labelLarge?.copyWith(
                  color: alerte ? vally.attention : theme.colorScheme.onSurfaceVariant)),
        ),
        ?detail,
      ]),
    );
  }
}

/// Avatar rond avec initiales.
class AvatarInitiales extends StatelessWidget {
  const AvatarInitiales(this.initiales, {super.key, this.taille = 40});

  final String initiales;
  final double taille;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CircleAvatar(
      radius: taille / 2,
      backgroundColor: theme.colorScheme.primaryContainer,
      foregroundColor: theme.colorScheme.onPrimaryContainer,
      child: Text(initiales.isEmpty ? '?' : initiales,
          style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontSize: taille * 0.36)),
    );
  }
}

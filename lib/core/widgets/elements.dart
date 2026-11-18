import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../theme/app_theme.dart';

/// Barre fixée en bas pour l'action principale : bouton 46 px pleine
/// largeur (ou à droite d'un résumé), spinner quand c'est en cours.
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
    final bouton = FilledButton(
      onPressed: enCours || onPressed == null
          ? null
          : () {
              HapticFeedback.lightImpact();
              onPressed!();
            },
      child: enCours
          ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.2))
          : Row(mainAxisSize: MainAxisSize.min, children: [
              if (icone != null) ...[Icon(icone, size: 20), const SizedBox(width: 8)],
              Text(libelle),
            ]),
    );
    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
                top: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6))),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
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

/// Titre de section : MAJUSCULES 12 px, avec action facultative à droite.
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titre.toUpperCase(),
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
                if (sousTitre != null) ...[
                  const SizedBox(height: 2),
                  Text(sousTitre!, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                  minimumSize: const Size(40, 30), visualDensity: VisualDensity.compact),
              child: Text(action!),
            ),
        ],
      ),
    );
  }
}

/// Petite pastille d'état (tag) : icône + texte, rayon 20.
class Pastille extends StatelessWidget {
  const Pastille({super.key, required this.texte, this.icone, this.couleur, this.fond});

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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fond ?? c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(VallyRadius.lg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[Icon(icone, size: 13, color: c), const SizedBox(width: 4)],
          Flexible(
            child: Text(texte,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(color: c, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// Rangée de filtres (pilules) défilant horizontalement.
class RangeeFiltres extends StatelessWidget {
  const RangeeFiltres({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: VallySpace.s4),
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => Center(child: children[i]),
      ),
    );
  }
}

/// Pilule de filtre exclusif : rose si choisie, sinon fond neutre.
/// Compteur facultatif (« Aujourd'hui 3 »), retour haptique au toucher.
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
    final scheme = theme.colorScheme;
    final vally = theme.extension<VallyColors>()!;
    final texte = actif ? scheme.onPrimary : scheme.onSurface;
    return Semantics(
      button: true,
      selected: actif,
      label: compte != null && compte! > 0 ? '$libelle, $compte' : libelle,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(VallyRadius.lg),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: actif ? scheme.primary : scheme.onSurface.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(VallyRadius.lg),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icone != null) ...[Icon(icone, size: 16, color: texte), const SizedBox(width: 6)],
              Text(libelle,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: texte)),
              if (compte != null && compte! > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: actif
                        ? scheme.onPrimary.withValues(alpha: 0.22)
                        : (alerte ? vally.attention : scheme.primary),
                    borderRadius: BorderRadius.circular(VallyRadius.pill),
                  ),
                  child: Text(compte! > 9 ? '9+' : '$compte',
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onPrimary, fontWeight: FontWeight.w700)),
                ),
              ],
            ]),
          ),
        ),
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

/// Avatar rond avec initiales (fond rose à 12 %).
class AvatarInitiales extends StatelessWidget {
  const AvatarInitiales(this.initiales, {super.key, this.taille = 40});

  final String initiales;
  final double taille;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: taille / 2,
      backgroundColor: scheme.primary.withValues(alpha: 0.12),
      child: Text(initiales.isEmpty ? '?' : initiales,
          style: TextStyle(
              color: scheme.primary, fontWeight: FontWeight.w700, fontSize: taille * 0.36)),
    );
  }
}

/// Tuile d'icône : carré arrondi rose à 12 % (34 · 44 · 48 px).
class TuileIcone extends StatelessWidget {
  const TuileIcone(this.icone, {super.key, this.taille = 44, this.active = false, this.couleur});

  final IconData icone;
  final double taille;
  final bool active;
  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = couleur ?? scheme.primary;
    return Container(
      width: taille,
      height: taille,
      decoration: BoxDecoration(
        color: active ? c : c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(
            taille <= 34 ? VallyRadius.xs : (taille >= 48 ? VallyRadius.r14 : VallyRadius.sm)),
      ),
      child: Icon(icone, size: taille * 0.5, color: active ? scheme.onPrimary : c),
    );
  }
}

/// Note d'information discrète : icône + texte 13 px.
class NoteInfo extends StatelessWidget {
  const NoteInfo(this.texte, {super.key, this.icone = Icons.info_outline});

  final String texte;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(VallyRadius.sm),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icone, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: Text(texte,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
        ),
      ]),
    );
  }
}

/// Bloc gris du squelette de chargement.
class Squelette extends StatelessWidget {
  const Squelette({super.key, this.largeur, this.hauteur = 14, this.rayon = 6});

  final double? largeur;
  final double hauteur;
  final double rayon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: largeur,
      height: hauteur,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(rayon),
      ),
    );
  }
}

/// Chargement d'un écran de liste : la forme du contenu, sans spinner.
class ListeSquelette extends StatelessWidget {
  const ListeSquelette({super.key, this.avecResume = true, this.lignes = 6});

  final bool avecResume;
  final int lignes;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (avecResume) ...[
            const Squelette(hauteur: 96, rayon: VallyRadius.lg),
            const SizedBox(height: 14),
            const Row(children: [
              Squelette(largeur: 80, hauteur: 32, rayon: VallyRadius.lg),
              SizedBox(width: 8),
              Squelette(largeur: 96, hauteur: 32, rayon: VallyRadius.lg),
              SizedBox(width: 8),
              Squelette(largeur: 70, hauteur: 32, rayon: VallyRadius.lg),
            ]),
            const SizedBox(height: 18),
          ],
          for (var i = 0; i < lignes; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                const Squelette(largeur: 44, hauteur: 44, rayon: VallyRadius.sm),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Squelette(largeur: i.isEven ? 160 : 120),
                    const SizedBox(height: 8),
                    const Squelette(largeur: 90, hauteur: 10),
                  ]),
                ),
                const Squelette(largeur: 64),
              ]),
            ),
        ],
      ),
    );
  }
}

/// Confirmation simple : Annuler / Confirmer. [destructif] colore
/// le bouton en couleur d'erreur.
Future<bool> confirmer(
  BuildContext context, {
  required String titre,
  required String message,
  String bouton = 'Confirmer',
  bool destructif = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return AlertDialog(
        title: Text(titre),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(
            style: destructif
                ? FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                    minimumSize: const Size(64, 40))
                : FilledButton.styleFrom(minimumSize: const Size(64, 40)),
            onPressed: () => Navigator.pop(context, true),
            child: Text(bouton),
          ),
        ],
      );
    },
  );
  return ok == true;
}

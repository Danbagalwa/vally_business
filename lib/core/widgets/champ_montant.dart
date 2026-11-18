import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../theme/app_theme.dart';
import '../format/montant.dart';

/// Contrôleur d'un champ montant : texte saisi + devise de saisie.
/// Changer de devise convertit le montant déjà saisi.
class MontantSaisieController extends ChangeNotifier {
  MontantSaisieController({required Devise devise, num? initial})
      : _devise = devise,
        texte = TextEditingController(
          text: initial == null ? '' : FormatMontant.pourSaisie(initial, devise),
        ) {
    texte.addListener(_surTexte);
  }

  final TextEditingController texte;
  Devise _devise;

  bool _interne = false;
  bool _modifie = false;

  /// Montant de référence affiché par l'appli (ex. : le total), pour le
  /// reconvertir exactement si on change de devise.
  num? _reference;
  Devise? _deviseReference;
  ArrondiDevise _arrondi = ArrondiDevise.proche;

  Devise get devise => _devise;

  /// Change la devise SANS convertir (préférer [basculer]).
  set devise(Devise valeur) {
    if (valeur == _devise) return;
    _devise = valeur;
    notifyListeners();
  }

  /// Vrai dès que la personne a tapé quelque chose elle-même.
  bool get modifieParUtilisateur => _modifie;

  void _surTexte() {
    if (!_interne) {
      _modifie = true;
      _reference = null;
    }
    notifyListeners();
  }

  void _ecrire(String t) {
    _interne = true;
    texte.text = t;
    _interne = false;
  }

  /// Valeur telle que saisie (dans [devise]).
  double? get valeur => FormatMontant.lire(texte.text);

  /// Valeur convertie dans la devise de référence de la boutique.
  double? enReference(Devise reference, num tauxUsdVersCdf) {
    final v = valeur;
    if (v == null) return null;
    return FormatMontant.arrondir(FormatMontant.convertir(v,
        de: devise, vers: reference, tauxUsdVersCdf: tauxUsdVersCdf));
  }

  /// Affiche un montant connu (en devise de référence) dans la devise
  /// choisie, sans le compter comme une saisie.
  void afficherDepuisReference(
    num? montant, {
    required Devise reference,
    required num tauxUsdVersCdf,
    ArrondiDevise arrondi = ArrondiDevise.proche,
  }) {
    _reference = montant;
    _deviseReference = reference;
    _arrondi = arrondi;
    _modifie = false;
    if (montant == null || montant <= 0) {
      _ecrire('');
      return;
    }
    final converti = FormatMontant.convertir(montant,
        de: reference, vers: _devise, tauxUsdVersCdf: tauxUsdVersCdf);
    _ecrire(FormatMontant.pourSaisie(
        FormatMontant.arrondirPour(converti, _devise, arrondi), _devise));
  }

  /// Change de devise en convertissant ce qui est déjà saisi
  /// (28 000 CDF → 10 USD au taux de 2 800).
  void basculer(Devise nouvelle, {required num tauxUsdVersCdf}) {
    if (nouvelle == _devise) return;
    final ancienne = _devise;
    _devise = nouvelle;
    if (_reference != null && _deviseReference != null) {
      // Montant venant de l'appli : on repart du montant exact.
      afficherDepuisReference(_reference,
          reference: _deviseReference!, tauxUsdVersCdf: tauxUsdVersCdf, arrondi: _arrondi);
    } else {
      final v = valeur;
      if (v != null) {
        final converti = FormatMontant.convertir(v,
            de: ancienne, vers: nouvelle, tauxUsdVersCdf: tauxUsdVersCdf);
        final modifie = _modifie;
        _ecrire(FormatMontant.pourSaisie(
            FormatMontant.arrondirPour(converti, nouvelle), nouvelle));
        _modifie = modifie;
      }
    }
    notifyListeners();
  }

  /// Vide le champ et oublie les saisies précédentes.
  void vider() {
    _reference = null;
    _ecrire('');
    _modifie = false;
  }

  @override
  void dispose() {
    texte.removeListener(_surTexte);
    texte.dispose();
    super.dispose();
  }
}

/// Champ de saisie d'un montant, en CDF ou en USD au choix.
/// La bascule CDF | USD convertit le montant ; l'équivalent dans l'autre
/// devise s'affiche sous le champ.
class ChampMontant extends StatelessWidget {
  const ChampMontant({
    super.key,
    required this.controller,
    required this.label,
    required this.deviseReference,
    required this.tauxUsdVersCdf,
    this.aide,
    this.obligatoire = true,
    this.zeroAutorise = true,
    this.textInputAction = TextInputAction.next,
  });

  final MontantSaisieController controller;
  final String label;
  final Devise deviseReference;
  final num tauxUsdVersCdf;
  final String? aide;
  final bool obligatoire;
  final bool zeroAutorise;
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final v = controller.valeur;
        String? equivalent;
        if (v != null && v > 0) {
          final autre = controller.devise.autre;
          final converti = FormatMontant.convertir(v,
              de: controller.devise, vers: autre, tauxUsdVersCdf: tauxUsdVersCdf);
          equivalent = '≈ ${FormatMontant.formater(converti, autre)}'
              '  (1 USD = ${FormatMontant.formater(tauxUsdVersCdf, Devise.cdf)})';
        }
        final aideAffichee = [?aide, ?equivalent].join('\n');
        return TextFormField(
          controller: controller.texte,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: textInputAction,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.\s]'))],
          style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
          decoration: InputDecoration(
            labelText: label,
            helperText: aideAffichee.isEmpty ? null : aideAffichee,
            helperMaxLines: 3,
            suffixIcon: Padding(
              padding: const EdgeInsetsDirectional.only(end: 6),
              child: BasculeDevise(
                devise: controller.devise,
                onChanged: (d) => controller.basculer(d, tauxUsdVersCdf: tauxUsdVersCdf),
              ),
            ),
          ),
          validator: (texte) {
            final v = FormatMontant.lire(texte ?? '');
            if (v == null) {
              if ((texte ?? '').trim().isEmpty) {
                return obligatoire ? 'Saisis un montant.' : null;
              }
              return 'Montant invalide.';
            }
            if (v < 0) return 'Le montant ne peut pas être négatif.';
            if (!zeroAutorise && v == 0) return 'Saisis un montant supérieur à 0.';
            return null;
          },
        );
      },
    );
  }
}

/// Petite bascule « CDF | USD », toujours visible.
class BasculeDevise extends StatelessWidget {
  const BasculeDevise({super.key, required this.devise, required this.onChanged});

  final Devise devise;
  final ValueChanged<Devise> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget option(Devise d) {
      final actif = d == devise;
      return Semantics(
        button: true,
        selected: actif,
        label: d == Devise.cdf ? 'Saisir en francs congolais' : 'Saisir en dollars',
        child: InkWell(
          onTap: actif ? null : () => onChanged(d),
          borderRadius: BorderRadius.circular(VallyRadius.pill),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: actif ? theme.colorScheme.primaryContainer : null,
              borderRadius: BorderRadius.circular(VallyRadius.pill),
            ),
            child: Text(
              d.code,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: actif ? FontWeight.w700 : FontWeight.w500,
                color: actif ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(VallyRadius.pill),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        option(Devise.cdf),
        option(Devise.usd),
      ]),
    );
  }
}

/// « ≈ 10,00 USD » : un montant (devise de référence) dans l'autre devise.
class EquivalentDevise extends StatelessWidget {
  const EquivalentDevise({
    super.key,
    required this.montant,
    required this.deviseReference,
    required this.tauxUsdVersCdf,
    this.style,
  });

  final num montant;
  final Devise deviseReference;
  final num tauxUsdVersCdf;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    if (montant.abs() < 0.005) return const SizedBox.shrink();
    final autre = deviseReference.autre;
    final converti = FormatMontant.convertir(montant.abs(),
        de: deviseReference, vers: autre, tauxUsdVersCdf: tauxUsdVersCdf);
    return Text('≈ ${FormatMontant.formater(converti, autre)}',
        style: (style ?? Theme.of(context).textTheme.bodySmall)
            ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]));
  }
}

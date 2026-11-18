import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../format/montant.dart';

/// Contrôleur d'un champ montant : texte saisi + devise de saisie.
class MontantSaisieController extends ChangeNotifier {
  MontantSaisieController({required Devise devise, num? initial})
      : _devise = devise,
        texte = TextEditingController(
          text: initial == null ? '' : FormatMontant.pourSaisie(initial, devise),
        ) {
    texte.addListener(notifyListeners);
  }

  final TextEditingController texte;
  Devise _devise;

  Devise get devise => _devise;

  set devise(Devise valeur) {
    if (valeur == _devise) return;
    _devise = valeur;
    notifyListeners();
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

  @override
  void dispose() {
    texte.removeListener(notifyListeners);
    texte.dispose();
    super.dispose();
  }
}

/// Champ de saisie d'un montant, en CDF ou en USD.
/// Le bouton à droite change la devise de saisie ; si elle diffère de la
/// devise de référence, la conversion s'affiche sous le champ.
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
        final convertie = controller.devise != deviseReference
            ? controller.enReference(deviseReference, tauxUsdVersCdf)
            : null;
        final aideAffichee = convertie != null
            ? '≈ ${FormatMontant.formater(convertie, deviseReference)} '
                '(1 USD = ${FormatMontant.formater(tauxUsdVersCdf, Devise.cdf)})'
            : aide;
        return TextFormField(
          controller: controller.texte,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: textInputAction,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9,.\s]')),
          ],
          style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
          decoration: InputDecoration(
            labelText: label,
            helperText: aideAffichee,
            helperMaxLines: 2,
            suffixIcon: Padding(
              padding: const EdgeInsetsDirectional.only(end: 4),
              child: TextButton(
                onPressed: () => controller.devise = controller.devise.autre,
                child: Text(controller.devise.code),
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

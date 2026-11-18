import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format/montant.dart';

/// Champ « 1 USD = … CDF ».
class ChampTaux extends StatelessWidget {
  const ChampTaux({super.key, required this.controller, this.aide});

  final TextEditingController controller;
  final String? aide;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.\s]'))],
      style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
      decoration: InputDecoration(
        labelText: 'Taux de change',
        prefixText: '1 USD = ',
        suffixText: 'CDF',
        helperText: aide,
      ),
      validator: (v) {
        final taux = FormatMontant.lire(v ?? '');
        if (taux == null || taux <= 0) return 'Saisis le taux du jour.';
        return null;
      },
    );
  }
}

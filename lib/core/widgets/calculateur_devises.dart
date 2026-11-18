import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../theme/app_theme.dart';
import '../format/calcul.dart';
import '../format/montant.dart';

/// Calculateur USD ⇄ CDF au taux donné. Chaque champ accepte un calcul
/// (« 25*3 », « 120 000 + 35 000 ») : l'autre champ se met à jour.
class CalculateurDevises extends StatefulWidget {
  const CalculateurDevises({super.key, required this.tauxUsdVersCdf});

  /// 1 USD = x CDF (peut changer pendant la saisie du taux).
  final double tauxUsdVersCdf;

  @override
  State<CalculateurDevises> createState() => _CalculateurDevisesState();
}

class _CalculateurDevisesState extends State<CalculateurDevises> {
  final _usd = TextEditingController();
  final _cdf = TextEditingController();

  /// Champ tapé en dernier : l'autre en est déduit.
  Devise _source = Devise.usd;

  @override
  void didUpdateWidget(CalculateurDevises ancien) {
    super.didUpdateWidget(ancien);
    // Nouveau taux : on recalcule le champ déduit.
    if (ancien.tauxUsdVersCdf != widget.tauxUsdVersCdf) _recalculer();
  }

  @override
  void dispose() {
    _usd.dispose();
    _cdf.dispose();
    super.dispose();
  }

  TextEditingController _champ(Devise d) => d == Devise.usd ? _usd : _cdf;

  void _recalculer() {
    final taux = widget.tauxUsdVersCdf;
    final cible = _champ(_source.autre);
    final valeur = evaluerCalcul(_champ(_source).text);
    if (valeur == null || taux <= 0) {
      cible.text = '';
    } else {
      final converti = FormatMontant.convertir(valeur,
          de: _source, vers: _source.autre, tauxUsdVersCdf: taux);
      cible.text = _afficher(converti, _source.autre);
    }
    setState(() {});
  }

  /// « 280 000 », « 12,50 » (espaces fines pour les milliers).
  static String _afficher(num v, Devise d) =>
      FormatMontant.formater(v, d).replaceAll(' ${d.code}', '');

  void _vider() {
    _usd.clear();
    _cdf.clear();
    setState(() {});
  }

  void _echanger() {
    final valeur = evaluerCalcul(_champ(_source).text);
    if (valeur == null) return;
    // Le résultat devient la nouvelle saisie.
    final converti = FormatMontant.convertir(valeur,
        de: _source, vers: _source.autre, tauxUsdVersCdf: widget.tauxUsdVersCdf);
    _source = _source.autre;
    _champ(_source).text = FormatMontant.pourSaisie(
        FormatMontant.arrondirPour(converti, _source), _source);
    _recalculer();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget champ(Devise d) {
      final saisie = _champ(d).text;
      final resultat = d == _source && estUnCalcul(saisie) ? evaluerCalcul(saisie) : null;
      return TextField(
        controller: _champ(d),
        keyboardType: TextInputType.text,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.\s+\-*/×÷xX]'))],
        style: theme.textTheme.titleSmall,
        onChanged: (_) {
          _source = d;
          _recalculer();
        },
        decoration: InputDecoration(
          labelText: d == Devise.usd ? 'Dollars' : 'Francs congolais',
          suffixText: d.code,
          helperText: resultat == null ? null : '= ${FormatMontant.formater(resultat, d)}',
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      champ(Devise.usd),
      Row(children: [
        const Expanded(child: Divider()),
        IconButton(
          tooltip: 'Inverser le calcul',
          icon: const Icon(Icons.swap_vert),
          onPressed: _echanger,
        ),
        const Expanded(child: Divider()),
      ]),
      champ(Devise.cdf),
      const SizedBox(height: VallySpace.s2),
      Row(children: [
        Expanded(
          child: Text(
            '1 USD = ${FormatMontant.formater(widget.tauxUsdVersCdf, Devise.cdf)}  ·  '
            'Tu peux taper un calcul : 25*3, 120000+35000',
            style: theme.textTheme.bodySmall,
          ),
        ),
        TextButton(onPressed: _vider, child: const Text('Effacer')),
      ]),
    ]);
  }
}

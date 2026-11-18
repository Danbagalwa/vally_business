import 'package:material_ui/material_ui.dart';

import '../../../../core/format/montant.dart';
import '../../../../core/widgets/champ_montant.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/commande.dart';

/// Choix du mode de paiement (pastilles).
class ChoixModePaiement extends StatelessWidget {
  const ChoixModePaiement({super.key, required this.mode, required this.onChanged});

  final ModePaiement mode;
  final ValueChanged<ModePaiement> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: VallySpace.s2,
      runSpacing: VallySpace.s2,
      children: [
        for (final m in ModePaiement.values)
          ChoiceChip(
            label: Text(m.libelle),
            selected: m == mode,
            showCheckmark: false,
            onSelected: (_) => onChanged(m),
          ),
      ],
    );
  }
}

/// Résultat du dialogue d'ajout de paiement.
class PaiementDialogue {
  const PaiementDialogue({
    required this.montantSaisi,
    required this.devise,
    required this.mode,
    required this.date,
  });

  final double montantSaisi;
  final Devise devise;
  final ModePaiement mode;
  final DateTime date;
}

/// Dialogue « Ajouter un paiement », pré-rempli avec le reste à payer.
Future<PaiementDialogue?> demanderPaiement(
  BuildContext context, {
  required double resteAPayer,
  required Devise deviseReference,
  required double tauxUsdCdf,
}) {
  return showModalBottomSheet<PaiementDialogue>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _FeuillePaiement(
      resteAPayer: resteAPayer,
      deviseReference: deviseReference,
      tauxUsdCdf: tauxUsdCdf,
    ),
  );
}

class _FeuillePaiement extends StatefulWidget {
  const _FeuillePaiement({
    required this.resteAPayer,
    required this.deviseReference,
    required this.tauxUsdCdf,
  });

  final double resteAPayer;
  final Devise deviseReference;
  final double tauxUsdCdf;

  @override
  State<_FeuillePaiement> createState() => _FeuillePaiementState();
}

class _FeuillePaiementState extends State<_FeuillePaiement> {
  final _formKey = GlobalKey<FormState>();
  late final MontantSaisieController _montant = MontantSaisieController(
    devise: widget.deviseReference,
    initial: widget.resteAPayer > 0 ? widget.resteAPayer : null,
  );
  ModePaiement _mode = ModePaiement.especes;
  DateTime _date = DateUtils.dateOnly(DateTime.now());

  @override
  void dispose() {
    _montant.dispose();
    super.dispose();
  }

  Future<void> _choisirDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Date du paiement',
    );
    if (d != null) setState(() => _date = d);
  }

  void _valider() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      PaiementDialogue(
        montantSaisi: _montant.valeur!,
        devise: _montant.devise,
        mode: _mode,
        date: _date,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vally = theme.extension<VallyColors>()!;
    return Padding(
      padding: EdgeInsets.fromLTRB(VallySpace.s4, 0, VallySpace.s4,
          VallySpace.s4 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Ajouter un paiement', style: theme.textTheme.titleMedium),
            const SizedBox(height: VallySpace.s4),
            ChampMontant(
              controller: _montant,
              label: 'Montant reçu',
              deviseReference: widget.deviseReference,
              tauxUsdVersCdf: widget.tauxUsdCdf,
              zeroAutorise: false,
              textInputAction: TextInputAction.done,
            ),
            ListenableBuilder(
              listenable: _montant,
              builder: (context, _) {
                final v = _montant.enReference(
                    widget.deviseReference, widget.tauxUsdCdf);
                if (v == null || v <= widget.resteAPayer + 0.005) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: VallySpace.s2),
                  child: Row(children: [
                    Icon(Icons.info_outline, size: 16, color: vally.attention),
                    const SizedBox(width: VallySpace.s1),
                    Expanded(
                      child: Text('C’est plus que le reste à payer.',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: vally.attention)),
                    ),
                  ]),
                );
              },
            ),
            const SizedBox(height: VallySpace.s4),
            Text('Mode', style: theme.textTheme.labelLarge),
            const SizedBox(height: VallySpace.s2),
            ChoixModePaiement(mode: _mode, onChanged: (m) => setState(() => _mode = m)),
            const SizedBox(height: VallySpace.s4),
            OutlinedButton.icon(
              onPressed: _choisirDate,
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(MaterialLocalizations.of(context).formatMediumDate(_date)),
            ),
            const SizedBox(height: VallySpace.s4),
            FilledButton(onPressed: _valider, child: const Text('Enregistrer le paiement')),
          ],
        ),
      ),
    );
  }
}

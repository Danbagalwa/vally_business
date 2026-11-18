import 'package:material_ui/material_ui.dart';

import '../../../../core/format/dates.dart';
import '../../../../core/format/montant.dart';
import '../../../../core/widgets/champ_montant.dart';
import '../../../../core/widgets/montant_texte.dart';
import '../../../../theme/app_theme.dart';
import '../../../boutique/domain/boutique.dart';
import '../../domain/mouvement.dart';

/// Ajout (ou modification) d'une entrée / sortie d'argent.
Future<MouvementSaisie?> demanderMouvement(
  BuildContext context, {
  required Boutique boutique,
  Mouvement? existant,
}) {
  return showModalBottomSheet<MouvementSaisie>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _FeuilleMouvement(boutique: boutique, existant: existant),
  );
}

class _FeuilleMouvement extends StatefulWidget {
  const _FeuilleMouvement({required this.boutique, this.existant});

  final Boutique boutique;
  final Mouvement? existant;

  @override
  State<_FeuilleMouvement> createState() => _FeuilleMouvementState();
}

class _FeuilleMouvementState extends State<_FeuilleMouvement> {
  final _formKey = GlobalKey<FormState>();
  late TypeMouvement _type = widget.existant?.type ?? TypeMouvement.sortie;
  late final _montant = MontantSaisieController(
    devise: widget.existant?.deviseSaisie ?? widget.boutique.devise,
    initial: widget.existant?.montantSaisi,
  );
  late final _categorie = TextEditingController(text: widget.existant?.categorie);
  late final _note = TextEditingController(text: widget.existant?.note);
  late DateTime _date = widget.existant?.date ?? DateUtils.dateOnly(DateTime.now());

  @override
  void dispose() {
    _montant.dispose();
    _categorie.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _choisirDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _date = d);
  }

  void _valider() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      MouvementSaisie(
        type: _type,
        montantSaisi: _montant.valeur!,
        devise: _montant.devise,
        categorie: _categorie.text,
        date: _date,
        note: _note.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suggestions = _type == TypeMouvement.sortie ? categoriesSortie : categoriesEntree;
    final aujourdhui = DateUtils.dateOnly(DateTime.now());
    final hier = aujourdhui.subtract(const Duration(days: 1));
    return Padding(
      padding: EdgeInsets.fromLTRB(
          VallySpace.s4, 0, VallySpace.s4, VallySpace.s4 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.existant == null ? 'Nouveau mouvement' : 'Modifier', style: theme.textTheme.titleMedium),
              const SizedBox(height: VallySpace.s4),
              SegmentedButton<TypeMouvement>(
                segments: const [
                  ButtonSegment(
                      value: TypeMouvement.sortie,
                      icon: Icon(Icons.arrow_upward, size: 18),
                      label: Text('Sortie')),
                  ButtonSegment(
                      value: TypeMouvement.entree,
                      icon: Icon(Icons.arrow_downward, size: 18),
                      label: Text('Entrée')),
                ],
                selected: {_type},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: VallySpace.s4),
              ChampMontant(
                controller: _montant,
                label: 'Montant',
                deviseReference: widget.boutique.devise,
                tauxUsdVersCdf: widget.boutique.tauxUsdCdf,
                zeroAutorise: false,
              ),
              const SizedBox(height: VallySpace.s4),
              TextFormField(
                controller: _categorie,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Catégorie'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Choisis une catégorie.' : null,
              ),
              const SizedBox(height: VallySpace.s2),
              ListenableBuilder(
                listenable: _categorie,
                builder: (context, _) => Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final c in suggestions)
                    ChoiceChip(
                      label: Text(c),
                      selected: _categorie.text.trim() == c,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => _categorie.text = c,
                    ),
                ]),
              ),
              const SizedBox(height: VallySpace.s4),
              Wrap(spacing: 6, runSpacing: 6, children: [
                ChoiceChip(
                  label: const Text('Aujourd’hui'),
                  selected: _date == aujourdhui,
                  onSelected: (_) => setState(() => _date = aujourdhui),
                ),
                ChoiceChip(
                  label: const Text('Hier'),
                  selected: _date == hier,
                  onSelected: (_) => setState(() => _date = hier),
                ),
                ChoiceChip(
                  avatar: const Icon(Icons.event, size: 16),
                  label: Text(_date != aujourdhui && _date != hier ? FormatDate.relatif(_date) : 'Autre date'),
                  selected: _date != aujourdhui && _date != hier,
                  onSelected: (_) => _choisirDate(),
                ),
              ]),
              const SizedBox(height: VallySpace.s4),
              TextFormField(
                controller: _note,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Note (facultatif)'),
              ),
              const SizedBox(height: VallySpace.s6),
              FilledButton(onPressed: _valider, child: const Text('Enregistrer')),
            ],
          ),
        ),
      ),
    );
  }
}

/// Résultat de la feuille « Me verser un bénéfice ».
class Versement {
  const Versement({required this.montantSaisi, required this.devise, required this.date, this.note});

  final double montantSaisi;
  final Devise devise;
  final DateTime date;
  final String? note;
}

/// « Me verser un bénéfice » : au plus le bénéfice encaissé disponible.
Future<Versement?> demanderVersement(
  BuildContext context, {
  required Boutique boutique,
  required double disponible,
}) {
  return showModalBottomSheet<Versement>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _FeuilleVersement(boutique: boutique, disponible: disponible),
  );
}

class _FeuilleVersement extends StatefulWidget {
  const _FeuilleVersement({required this.boutique, required this.disponible});

  final Boutique boutique;
  final double disponible;

  @override
  State<_FeuilleVersement> createState() => _FeuilleVersementState();
}

class _FeuilleVersementState extends State<_FeuilleVersement> {
  final _formKey = GlobalKey<FormState>();
  late final _montant = MontantSaisieController(devise: widget.boutique.devise);
  final _note = TextEditingController();

  @override
  void dispose() {
    _montant.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _depasse {
    final v = _montant.enReference(widget.boutique.devise, widget.boutique.tauxUsdCdf);
    return v != null && v > widget.disponible + 0.005;
  }

  void _valider() {
    if (!_formKey.currentState!.validate() || _depasse) return;
    Navigator.pop(
      context,
      Versement(
        montantSaisi: _montant.valeur!,
        devise: _montant.devise,
        date: DateUtils.dateOnly(DateTime.now()),
        note: _note.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vally = theme.extension<VallyColors>()!;
    final devise = widget.boutique.devise;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          VallySpace.s4, 0, VallySpace.s4, VallySpace.s4 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Me verser un bénéfice', style: theme.textTheme.titleMedium),
            const SizedBox(height: VallySpace.s2),
            TexteAvecMontants([
              'Disponible : ',
              spanMontant(context, widget.disponible, devise, sens: SensMontant.positif, gras: true),
              '  ≈ ${FormatMontant.formater(FormatMontant.convertir(widget.disponible, de: devise, vers: devise.autre, tauxUsdVersCdf: widget.boutique.tauxUsdCdf), devise.autre)}',
            ], style: theme.textTheme.bodyMedium),
            Text('Seul le bénéfice des ventes payées en entier peut être versé.',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: VallySpace.s4),
            ChampMontant(
              controller: _montant,
              label: 'Montant à te verser',
              deviseReference: devise,
              tauxUsdVersCdf: widget.boutique.tauxUsdCdf,
              zeroAutorise: false,
            ),
            ListenableBuilder(
              listenable: _montant,
              builder: (context, _) => _depasse
                  ? Padding(
                      padding: const EdgeInsets.only(top: VallySpace.s2),
                      child: Row(children: [
                        Icon(Icons.warning_amber_rounded, size: 16, color: vally.attention),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('C’est plus que le bénéfice disponible.',
                              style: theme.textTheme.bodySmall?.copyWith(color: vally.attention)),
                        ),
                      ]),
                    )
                  : const SizedBox.shrink(),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                // Dans la devise choisie, arrondi vers le bas : jamais plus
                // que le disponible.
                onPressed: () => _montant.afficherDepuisReference(
                  widget.disponible,
                  reference: devise,
                  tauxUsdVersCdf: widget.boutique.tauxUsdCdf,
                  arrondi: ArrondiDevise.bas,
                ),
                child: const Text('Tout le disponible'),
              ),
            ),
            TextFormField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Note (facultatif)', hintText: 'Ex. : pour le loyer'),
            ),
            const SizedBox(height: VallySpace.s6),
            FilledButton(onPressed: _valider, child: const Text('Me verser ce montant')),
          ],
        ),
      ),
    );
  }
}

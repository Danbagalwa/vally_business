import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format/montant.dart';
import '../../../core/widgets/menu_compte.dart';
import '../../../core/widgets/page_erreur.dart';
import '../../../theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../data/boutique_repository.dart';
import 'champ_taux.dart';

/// Premier écran d'un compte sans boutique.
class BienvenuePage extends ConsumerStatefulWidget {
  const BienvenuePage({super.key});

  @override
  ConsumerState<BienvenuePage> createState() => _BienvenuePageState();
}

class _BienvenuePageState extends ConsumerState<BienvenuePage> {
  final _formKey = GlobalKey<FormState>();
  final _nom = TextEditingController();
  final _taux = TextEditingController();
  Devise _devise = Devise.cdf;
  bool _enCours = false;

  @override
  void dispose() {
    _nom.dispose();
    _taux.dispose();
    super.dispose();
  }

  Future<void> _creer() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enCours = true);
    try {
      await ref.read(boutiqueRepositoryProvider).creer(
            nom: _nom.text.trim(),
            devise: _devise,
            tauxUsdCdf: FormatMontant.lire(_taux.text)!,
          );
      ref.invalidate(boutiqueProvider);
    } catch (e) {
      if (mounted) afficherErreur(context, e);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final email = ref.watch(authRepositoryProvider).utilisateurActuel?.email;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bienvenue'),
        actions: const [MenuCompte()],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(VallySpace.s4),
          children: [
            Text('Crée ta boutique pour commencer.',
                style: theme.textTheme.bodyLarge),
            const SizedBox(height: VallySpace.s4),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(VallySpace.s4),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Créer ma boutique',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: VallySpace.s4),
                      TextFormField(
                        controller: _nom,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                            labelText: 'Nom de la boutique'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Donne un nom à ta boutique.'
                            : null,
                      ),
                      const SizedBox(height: VallySpace.s4),
                      Text('Devise de référence',
                          style: theme.textTheme.labelLarge),
                      const SizedBox(height: VallySpace.s2),
                      SegmentedButton<Devise>(
                        segments: const [
                          ButtonSegment(
                              value: Devise.cdf, label: Text('Franc (CDF)')),
                          ButtonSegment(
                              value: Devise.usd, label: Text('Dollar (USD)')),
                        ],
                        selected: {_devise},
                        onSelectionChanged: (s) =>
                            setState(() => _devise = s.first),
                      ),
                      const SizedBox(height: VallySpace.s2),
                      Text(
                        'Tous tes montants seront enregistrés dans cette devise. '
                        'Tu pourras quand même saisir dans l’autre : '
                        'la conversion est automatique. '
                        'Ce choix ne pourra plus être changé.',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: VallySpace.s4),
                      ChampTaux(controller: _taux),
                      const SizedBox(height: VallySpace.s6),
                      FilledButton(
                        onPressed: _enCours ? null : _creer,
                        child: _enCours
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : const Text('Créer ma boutique'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: VallySpace.s4),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(VallySpace.s4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Tu rejoins une boutique existante ?',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: VallySpace.s2),
                    Text(
                      'Donne ton email à la personne qui gère la boutique. '
                      'Elle t’ajoute depuis « Ma boutique », puis tu actualises.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (email != null) ...[
                      const SizedBox(height: VallySpace.s2),
                      SelectableText(email,
                          style: theme.textTheme.titleSmall),
                    ],
                    const SizedBox(height: VallySpace.s4),
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(boutiqueProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Actualiser'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

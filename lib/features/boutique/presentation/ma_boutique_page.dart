import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format/dates.dart';
import '../../../core/format/montant.dart';
import '../../../core/widgets/page_erreur.dart';
import '../../../theme/app_theme.dart';
import '../data/boutique_repository.dart';
import '../domain/boutique.dart';
import 'champ_taux.dart';

/// Réglages de la boutique : nom, taux de change, membres.
class MaBoutiquePage extends ConsumerStatefulWidget {
  const MaBoutiquePage({super.key});

  @override
  ConsumerState<MaBoutiquePage> createState() => _MaBoutiquePageState();
}

class _MaBoutiquePageState extends ConsumerState<MaBoutiquePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nom;
  late final TextEditingController _taux;
  bool _enCours = false;

  @override
  void initState() {
    super.initState();
    final boutique = ref.read(boutiqueActiveProvider);
    _nom = TextEditingController(text: boutique.nom);
    _taux = TextEditingController(
        text: FormatMontant.pourSaisie(boutique.tauxUsdCdf, Devise.usd)
            .replaceAll(RegExp(r',00$'), ''));
  }

  @override
  void dispose() {
    _nom.dispose();
    _taux.dispose();
    super.dispose();
  }

  Future<void> _enregistrer(Boutique boutique) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enCours = true);
    try {
      await ref.read(boutiqueRepositoryProvider).modifier(
            boutique.id,
            nom: _nom.text.trim(),
            tauxUsdCdf: FormatMontant.lire(_taux.text),
          );
      ref.invalidate(boutiqueProvider);
      if (mounted) afficherSucces(context, 'Boutique enregistrée.');
    } catch (e) {
      if (mounted) afficherErreur(context, e);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  Future<void> _ajouterMembre() async {
    final email = await showDialog<String>(
      context: context,
      builder: (context) => const _DialogueAjoutMembre(),
    );
    if (email == null || !mounted) return;
    try {
      await ref.read(boutiqueRepositoryProvider).ajouterMembre(email);
      ref.invalidate(membresProvider);
      if (mounted) afficherSucces(context, '$email fait partie de ta boutique.');
    } catch (e) {
      if (mounted) afficherErreur(context, e);
    }
  }

  Future<void> _retirerMembre(Membre membre) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer ce membre ?'),
        content: Text('${membre.email} n’aura plus accès à la boutique. '
            'Ce qu’il a enregistré reste en place.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Retirer')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(boutiqueRepositoryProvider).retirerMembre(membre.userId);
      ref.invalidate(membresProvider);
    } catch (e) {
      if (mounted) afficherErreur(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final boutique = ref.watch(boutiqueActiveProvider);
    final membres = ref.watch(membresProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ma boutique')),
      body: ListView(
        padding: const EdgeInsets.all(VallySpace.s4),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(VallySpace.s4),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nom,
                      textCapitalization: TextCapitalization.words,
                      decoration:
                          const InputDecoration(labelText: 'Nom de la boutique'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Donne un nom à ta boutique.'
                          : null,
                    ),
                    const SizedBox(height: VallySpace.s4),
                    ChampTaux(
                      controller: _taux,
                      aide: 'Mis à jour le ${FormatDate.court(boutique.tauxMajLe)}',
                    ),
                    const SizedBox(height: VallySpace.s4),
                    Text(
                      'Devise de référence : ${boutique.devise.code}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: VallySpace.s4),
                    FilledButton(
                      onPressed: _enCours ? null : () => _enregistrer(boutique),
                      child: const Text('Enregistrer'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: VallySpace.s6),
          Text('Membres', style: theme.textTheme.titleMedium),
          const SizedBox(height: VallySpace.s2),
          Text('Chaque membre voit et gère tout : stock, ventes et dépenses.',
              style: theme.textTheme.bodySmall),
          const SizedBox(height: VallySpace.s2),
          membres.when(
            data: (liste) => Card(
              child: Column(
                children: [
                  for (final m in liste)
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(m.email),
                      subtitle: Text(m.estMoi
                          ? 'Toi · depuis le ${FormatDate.court(m.depuis)}'
                          : 'Depuis le ${FormatDate.court(m.depuis)}'),
                      trailing: m.estMoi || liste.length <= 1
                          ? null
                          : IconButton(
                              tooltip: 'Retirer',
                              icon: const Icon(Icons.person_remove_outlined),
                              onPressed: () => _retirerMembre(m),
                            ),
                    ),
                ],
              ),
            ),
            loading: () => const Padding(
              padding: EdgeInsets.all(VallySpace.s4),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => PageErreur(
              erreur: e,
              onReessayer: () => ref.invalidate(membresProvider),
            ),
          ),
          const SizedBox(height: VallySpace.s4),
          OutlinedButton.icon(
            onPressed: _ajouterMembre,
            icon: const Icon(Icons.person_add_alt),
            label: const Text('Ajouter un membre'),
          ),
        ],
      ),
    );
  }
}

class _DialogueAjoutMembre extends StatefulWidget {
  const _DialogueAjoutMembre();

  @override
  State<_DialogueAjoutMembre> createState() => _DialogueAjoutMembreState();
}

class _DialogueAjoutMembreState extends State<_DialogueAjoutMembre> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _valider() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, _email.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajouter un membre'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('La personne doit d’abord créer son compte dans l’appli.'),
            const SizedBox(height: VallySpace.s4),
            TextFormField(
              controller: _email,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Son email'),
              onFieldSubmitted: (_) => _valider(),
              validator: (v) => (v == null || !v.contains('@'))
                  ? 'Saisis une adresse email valide.'
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler')),
        TextButton(onPressed: _valider, child: const Text('Ajouter')),
      ],
    );
  }
}

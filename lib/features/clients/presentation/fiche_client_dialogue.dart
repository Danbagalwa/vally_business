import 'package:material_ui/material_ui.dart';

import '../../../theme/app_theme.dart';

class FicheClient {
  const FicheClient({required this.nom, this.telephone});

  final String nom;
  final String? telephone;
}

/// Création ou modification d'un client (nom, téléphone).
Future<FicheClient?> demanderFicheClient(
  BuildContext context, {
  String? nom,
  String? telephone,
}) {
  return showModalBottomSheet<FicheClient>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _Feuille(nom: nom, telephone: telephone),
  );
}

class _Feuille extends StatefulWidget {
  const _Feuille({this.nom, this.telephone});

  final String? nom;
  final String? telephone;

  @override
  State<_Feuille> createState() => _FeuilleState();
}

class _FeuilleState extends State<_Feuille> {
  final _formKey = GlobalKey<FormState>();
  late final _nom = TextEditingController(text: widget.nom);
  late final _tel = TextEditingController(text: widget.telephone);

  @override
  void dispose() {
    _nom.dispose();
    _tel.dispose();
    super.dispose();
  }

  void _valider() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, FicheClient(nom: _nom.text.trim(), telephone: _tel.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          VallySpace.s4, 0, VallySpace.s4, VallySpace.s4 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.nom == null ? 'Nouveau client' : 'Modifier le client',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: VallySpace.s4),
            TextFormField(
              controller: _nom,
              autofocus: widget.nom == null,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                  labelText: 'Nom', prefixIcon: Icon(Icons.person_outline)),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Indique le nom.' : null,
            ),
            const SizedBox(height: VallySpace.s2 + VallySpace.s1),
            TextFormField(
              controller: _tel,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _valider(),
              decoration: const InputDecoration(
                  labelText: 'Téléphone (facultatif)', prefixIcon: Icon(Icons.phone_outlined)),
            ),
            const SizedBox(height: VallySpace.s6),
            FilledButton(onPressed: _valider, child: const Text('Enregistrer')),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../theme/app_theme.dart';
import '../data/auth_repository.dart';
import '../domain/erreur_auth.dart';

/// Écran de connexion / création de compte.
class ConnexionPage extends ConsumerStatefulWidget {
  const ConnexionPage({super.key});

  @override
  ConsumerState<ConnexionPage> createState() => _ConnexionPageState();
}

class _ConnexionPageState extends ConsumerState<ConnexionPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _motDePasse = TextEditingController();

  bool _modeCreation = false;
  bool _enCours = false;
  bool _masquer = true;
  String? _erreur;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _motDePasse.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _enCours = true;
      _erreur = null;
      _info = null;
    });
    final auth = ref.read(authRepositoryProvider);
    try {
      if (_modeCreation) {
        final pret = await auth.creerCompte(
          email: _email.text,
          motDePasse: _motDePasse.text,
        );
        if (!pret && mounted) {
          setState(() {
            _modeCreation = false;
            _info = 'Compte créé. Ouvre le lien reçu par email, '
                'puis connecte-toi.';
          });
        }
      } else {
        await auth.seConnecter(
          email: _email.text,
          motDePasse: _motDePasse.text,
        );
      }
      // La redirection vers les onglets est faite par le routeur.
    } on ErreurAuth catch (e) {
      if (mounted) setState(() => _erreur = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _erreur =
            'Connexion impossible. Vérifie ta connexion internet et réessaie.');
      }
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vally = theme.extension<VallyColors>()!;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(VallySpace.s6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset('assets/icon/app_icon_foreground.png',
                        height: 96),
                    const SizedBox(height: VallySpace.s4),
                    Text('Vally Business',
                        style: theme.textTheme.headlineSmall,
                        textAlign: TextAlign.center),
                    const SizedBox(height: VallySpace.s2),
                    Text(
                      'Ton stock, tes ventes et ton argent, au même endroit.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: VallySpace.s6),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'Saisis une adresse email valide.'
                          : null,
                    ),
                    const SizedBox(height: VallySpace.s4),
                    TextFormField(
                      controller: _motDePasse,
                      obscureText: _masquer,
                      autofillHints: [
                        _modeCreation
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _valider(),
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        suffixIcon: IconButton(
                          tooltip: _masquer
                              ? 'Afficher le mot de passe'
                              : 'Masquer le mot de passe',
                          icon: Icon(_masquer
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () =>
                              setState(() => _masquer = !_masquer),
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 8)
                          ? 'Au moins 8 caractères.'
                          : null,
                    ),
                    if (_erreur != null) ...[
                      const SizedBox(height: VallySpace.s4),
                      _Message(
                          icone: Icons.error_outline,
                          texte: _erreur!,
                          couleur: vally.attention),
                    ],
                    if (_info != null) ...[
                      const SizedBox(height: VallySpace.s4),
                      _Message(
                          icone: Icons.mark_email_read_outlined,
                          texte: _info!,
                          couleur: vally.benefice),
                    ],
                    const SizedBox(height: VallySpace.s6),
                    FilledButton(
                      onPressed: _enCours ? null : _valider,
                      child: _enCours
                          ? const SizedBox.square(
                              dimension: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))
                          : Text(_modeCreation
                              ? 'Créer mon compte'
                              : 'Se connecter'),
                    ),
                    const SizedBox(height: VallySpace.s2),
                    TextButton(
                      onPressed: _enCours
                          ? null
                          : () => setState(() {
                                _modeCreation = !_modeCreation;
                                _erreur = null;
                                _info = null;
                              }),
                      child: Text(_modeCreation
                          ? 'J’ai déjà un compte'
                          : 'Créer un compte'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(
      {required this.icone, required this.texte, required this.couleur});

  final IconData icone;
  final String texte;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, color: couleur, size: 20),
        const SizedBox(width: VallySpace.s2),
        Expanded(
          child: Text(texte,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: couleur)),
        ),
      ],
    );
  }
}

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/format/dates.dart';
import '../../../../core/format/montant.dart';
import '../../../../core/format/texte.dart';
import '../../../../core/widgets/champ_montant.dart';
import '../../../../core/widgets/montant_texte.dart';
import '../../../../core/widgets/page_erreur.dart';
import '../../../boutique/data/boutique_repository.dart';
import '../../../boutique/domain/boutique.dart';
import '../../data/stock_repository.dart';
import '../../domain/article.dart';

/// Ce que la feuille « Racheter » renvoie.
class Rachat {
  const Rachat({
    required this.quantite,
    required this.prixSaisi,
    required this.devise,
    required this.date,
    this.fournisseur,
  });

  final int quantite;

  /// Prix d'une pièce tel que saisi, dans [devise] (la base le convertit).
  final double prixSaisi;
  final Devise devise;
  final DateTime date;
  final String? fournisseur;
}

/// Racheter un article : la feuille, puis l'enregistrement, puis un mot
/// pour dire que c'est fait. Sert depuis le stock, la fiche et la page
/// « Réapprovisionner ». Retourne le rachat enregistré (null sinon).
Future<Rachat?> racheterArticle(BuildContext context, WidgetRef ref, Article article) async {
  final boutique = ref.read(boutiqueActiveProvider);
  // Prix proposé : celui du dernier achat (le coût moyen n'est pas un prix
  // qu'on a payé). Jamais racheté : c'est le prix d'achat de l'article.
  // Sur la fiche, l'historique est déjà chargé : pas de nouvel appel.
  var prixPropose = article.prixAchat;
  if (article.dejaRachete) {
    final historique = achatsArticleProvider(article.id);
    final abonnement = ref.listenManual(historique, (_, _) {});
    try {
      final achats = await ref.read(historique.future);
      if (achats.isNotEmpty) prixPropose = achats.first.prixAchat;
    } catch (_) {
      // Sans l'historique, on garde le coût actuel : le champ reste modifiable.
    } finally {
      abonnement.close();
    }
  }
  if (!context.mounted) return null;
  final rachat = await demanderRachat(context, article: article, boutique: boutique, prixPropose: prixPropose);
  if (rachat == null || !context.mounted) return null;
  try {
    await ref.read(stockRepositoryProvider).reapprovisionner(
          articleId: article.id,
          quantite: rachat.quantite,
          prixSaisi: rachat.prixSaisi,
          devise: rachat.devise,
          date: rachat.date,
          fournisseur: rachat.fournisseur,
        );
    ref.invalidate(articlesProvider);
    if (context.mounted) afficherSucces(context, '${pieces(rachat.quantite)} de plus en stock.');
    return rachat;
  } catch (e) {
    if (context.mounted) afficherErreur(context, e);
    return null;
  }
}

/// Feuille « Racheter » : combien, à quel prix, chez qui, quand.
Future<Rachat?> demanderRachat(
  BuildContext context, {
  required Article article,
  required Boutique boutique,
  double? prixPropose,
}) =>
    showModalBottomSheet<Rachat>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FeuilleRachat(
          article: article, boutique: boutique, prixPropose: prixPropose ?? article.prixAchat),
    );

class _FeuilleRachat extends StatefulWidget {
  const _FeuilleRachat({required this.article, required this.boutique, required this.prixPropose});

  final Article article;
  final Boutique boutique;

  /// Prix d'une pièce au dernier achat, en devise de référence.
  final double prixPropose;

  @override
  State<_FeuilleRachat> createState() => _FeuilleRachatState();
}

class _FeuilleRachatState extends State<_FeuilleRachat> {
  final _formKey = GlobalKey<FormState>();
  final _quantite = TextEditingController();

  /// Pré-rempli avec le prix du dernier achat : souvent, il n'a pas changé.
  late final _prix = MontantSaisieController(devise: widget.boutique.devise, initial: widget.prixPropose);
  late final _fournisseur = TextEditingController(text: widget.article.fournisseur);
  DateTime _date = DateUtils.dateOnly(DateTime.now());

  @override
  void dispose() {
    _quantite.dispose();
    _prix.dispose();
    _fournisseur.dispose();
    super.dispose();
  }

  Future<void> _choisirDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Date du rachat',
    );
    if (d != null) setState(() => _date = d);
  }

  void _valider() {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();
    Navigator.pop(
      context,
      Rachat(
        quantite: int.parse(_quantite.text.trim()),
        prixSaisi: _prix.valeur!,
        devise: _prix.devise,
        date: _date,
        fournisseur: _fournisseur.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = widget.article;
    final b = widget.boutique;
    final aujourdhui = DateUtils.dateOnly(DateTime.now());
    final hier = aujourdhui.subtract(const Duration(days: 1));
    final autreDate = _date != aujourdhui && _date != hier;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Racheter « ${a.nom} »',
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(phraseResteArticle(a),
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 20),
              TextFormField(
                controller: _quantite,
                autofocus: true,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
                decoration: const InputDecoration(labelText: 'Combien de pièces as-tu rachetées ?'),
                validator: (v) {
                  final q = int.tryParse(v?.trim() ?? '');
                  return (q == null || q <= 0) ? 'Saisis au moins 1 pièce.' : null;
                },
              ),
              const SizedBox(height: 16),
              ChampMontant(
                controller: _prix,
                label: 'Prix d’achat d’une pièce',
                aide: 'Tous frais compris : transport, douane, emballage.',
                deviseReference: b.devise,
                tauxUsdVersCdf: b.tauxUsdCdf,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fournisseur,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Fournisseur (facultatif)'),
              ),
              const SizedBox(height: 12),
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
                  label: Text(autreDate ? FormatDate.relatif(_date) : 'Autre date'),
                  selected: autreDate,
                  onSelected: (_) => _choisirDate(),
                ),
              ]),
              const SizedBox(height: 16),
              ListenableBuilder(
                listenable: Listenable.merge([_quantite, _prix]),
                builder: (context, _) => _ResumeRachat(
                  article: a,
                  quantite: int.tryParse(_quantite.text.trim()),
                  prix: _prix.enReference(b.devise, b.tauxUsdCdf),
                  devise: b.devise,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: _valider, child: const Text('Ajouter au stock')),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ce que le rachat va changer, dit simplement : combien de pièces tu
/// auras, ce que coûte désormais une pièce, ce que tu gagneras dessus.
class _ResumeRachat extends StatelessWidget {
  const _ResumeRachat({
    required this.article,
    required this.quantite,
    required this.prix,
    required this.devise,
  });

  final Article article;
  final int? quantite;
  final double? prix;
  final Devise devise;

  @override
  Widget build(BuildContext context) {
    final q = quantite;
    final p = prix;
    if (q == null || q <= 0 || p == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final a = article;
    final restant = a.quantiteRestante < 0 ? 0 : a.quantiteRestante;
    final cout = coutMoyenApresRachat(restant: restant, coutActuel: a.prixAchat, quantite: q, prix: p);
    final change = restant > 0 && (cout - a.prixAchat).abs() >= 0.005;
    final marge = a.prixVenteHabituel - cout;
    final style = theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.35);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Tu auras ${pieces(restant + q)} en boutique.',
            style: style?.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        TexteAvecMontants([
          change ? 'Coût moyen d’une pièce : ' : 'Coût d’une pièce : ',
          spanMontant(context, cout, devise, gras: true),
          if (change) ...[' (avant : ', spanMontant(context, a.prixAchat, devise), ')'],
          '.',
        ], style: style),
        const SizedBox(height: 2),
        TexteAvecMontants([
          if (marge >= 0) ...[
            'Au prix habituel, tu gagneras ',
            spanMontant(context, marge, devise, sens: SensMontant.positif, gras: true),
            ' par pièce.',
          ] else ...[
            'Attention : au prix habituel, tu perdrais ',
            spanMontant(context, -marge, devise, sens: SensMontant.negatif, gras: true),
            ' par pièce.',
          ],
        ], style: style),
      ]),
    );
  }
}

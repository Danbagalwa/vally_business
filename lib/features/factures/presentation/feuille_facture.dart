import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format/montant.dart';
import '../../../core/widgets/elements.dart';
import '../../../core/widgets/page_erreur.dart';
import '../../../theme/app_theme.dart';
import '../../boutique/domain/boutique.dart';
import '../../clients/domain/client_resume.dart';
import '../../ventes/domain/commande.dart';
import '../data/envoi_facture.dart';
import '../domain/facture.dart';

/// Feuille « Facture » : aperçu du message, envoi sur WhatsApp ou partage.
/// [apresEnregistrement] : proposée juste après une vente ou une commande.
Future<void> ouvrirFeuilleFacture(
  BuildContext context, {
  required CommandeDetail detail,
  required Boutique boutique,
  bool apresEnregistrement = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _FeuilleFacture(
      detail: detail,
      boutique: boutique,
      apresEnregistrement: apresEnregistrement,
    ),
  );
}

enum _Action { whatsApp, partage }

class _FeuilleFacture extends StatefulWidget {
  const _FeuilleFacture({required this.detail, required this.boutique, required this.apresEnregistrement});

  final CommandeDetail detail;
  final Boutique boutique;
  final bool apresEnregistrement;

  @override
  State<_FeuilleFacture> createState() => _FeuilleFactureState();
}

class _FeuilleFactureState extends State<_FeuilleFacture> {
  _Action? _enCours;

  Commande get _c => widget.detail.commande;
  /// WhatsApp ouvert directement sur la discussion : appli Android seulement.
  /// Sur le web (iPhone), tout passe par le menu de partage.
  bool get _whatsAppDirect => !kIsWeb && numeroWhatsApp(_c.clientTelephone) != null;

  Future<void> _envoyer(_Action action) async {
    HapticFeedback.lightImpact();
    setState(() => _enCours = action);
    try {
      await EnvoiFacture.envoyer(widget.detail, widget.boutique, versWhatsApp: action == _Action.whatsApp);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _enCours = null);
        afficherErreur(context, 'La facture n’a pas pu être préparée. Réessaie.');
      }
    }
  }

  Widget _spinner() =>
      const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.2));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final vally = theme.extension<VallyColors>()!;
    final occupe = _enCours != null;
    final message = messageRemerciement(_c, boutique: widget.boutique.nom, devise: widget.boutique.devise);
    final titre = widget.apresEnregistrement
        ? (_c.estCommande ? 'Commande enregistrée' : 'Vente enregistrée')
        : 'Facture';

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              if (widget.apresEnregistrement) ...[
                Icon(Icons.check_circle, color: vally.benefice, size: 22),
                const SizedBox(width: 8),
              ],
              Expanded(child: Text(titre, style: theme.textTheme.titleLarge)),
            ]),
            const SizedBox(height: 4),
            Text(
              'Facture n° ${_c.numero ?? '—'} · ${FormatMontant.formater(_c.total, widget.boutique.devise)}',
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),

            // Aperçu : la facture PDF + le message qui l'accompagne.
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(VallyRadius.sm),
                border: Border(left: BorderSide(color: scheme.primary, width: 3)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.picture_as_pdf_outlined, size: 16, color: scheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(nomFichierFacture(_c),
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(message, style: theme.textTheme.bodyMedium?.copyWith(height: 1.35)),
              ]),
            ),
            const SizedBox(height: 16),

            if (_whatsAppDirect) ...[
              FilledButton.icon(
                onPressed: occupe ? null : () => _envoyer(_Action.whatsApp),
                icon: _enCours == _Action.whatsApp ? _spinner() : const Icon(Icons.chat_outlined, size: 20),
                label: Text('Envoyer à ${_c.nomAffiche} sur WhatsApp', overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: occupe ? null : () => _envoyer(_Action.partage),
                icon: _enCours == _Action.partage ? _spinner() : const Icon(Icons.ios_share, size: 20),
                label: const Text('Partager autrement'),
              ),
            ] else ...[
              FilledButton.icon(
                onPressed: occupe ? null : () => _envoyer(_Action.partage),
                icon: _enCours == _Action.partage ? _spinner() : const Icon(Icons.ios_share, size: 20),
                label: const Text('Partager la facture'),
              ),
              const SizedBox(height: 10),
              const NoteInfo(kIsWeb
                  ? 'Dans le menu qui s’ouvre, choisis WhatsApp puis la discussion du client.'
                  : 'Ajoute le numéro du client dans sa fiche pour lui envoyer '
                      'la facture directement sur WhatsApp.'),
            ],
            const SizedBox(height: 4),
            TextButton(
              onPressed: occupe ? null : () => Navigator.pop(context),
              child: Text(widget.apresEnregistrement ? 'Plus tard' : 'Fermer'),
            ),
          ],
        ),
      ),
    );
  }
}

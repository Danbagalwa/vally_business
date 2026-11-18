import '../../../core/format/dates.dart';
import '../../../core/format/montant.dart';
import '../../ventes/domain/commande.dart';

/// Nom du fichier PDF : « Facture-2026-0042.pdf ».
String nomFichierFacture(Commande c) => 'Facture-${c.numero ?? c.id.substring(0, 8)}.pdf';

/// Message de remerciement envoyé avec la facture (tutoiement, sans « ! »).
String messageRemerciement(Commande c, {required String boutique, required Devise devise}) {
  String m(num v) => FormatMontant.formater(v, devise);
  final bonjour = c.clientNom == null ? 'Bonjour' : 'Bonjour ${c.clientNom}';
  final quoi = c.estCommande ? 'ta commande' : 'ton achat';
  final lignes = <String>[
    '$bonjour, merci pour $quoi chez $boutique.',
    'Voici ta facture n° ${c.numero ?? '—'} : ${m(c.total)}.',
  ];
  if (!c.annulee) {
    if (c.statutPaiement == StatutPaiement.soldee) {
      lignes.add('Tout est réglé, merci.');
    } else if (c.totalPaye > 0) {
      lignes.add('Tu as déjà payé ${m(c.totalPaye)}, il reste ${m(c.resteAPayer)} à régler.');
    } else {
      lignes.add('Montant à régler : ${m(c.resteAPayer)}.');
    }
    if (c.aLivrer && c.dateLivraison != null) {
      final quand = FormatDate.relatif(c.dateLivraison!).toLowerCase();
      final date = quand.startsWith('aujourd') || quand.startsWith('demain')
          ? quand
          : 'le ${FormatDate.court(c.dateLivraison!)}';
      lignes.add(c.modeRemise == ModeRemise.livraison
          ? 'Livraison prévue $date.'
          : 'Ta commande sera prête $date.');
    }
  }
  lignes.add('À bientôt.');
  return lignes.join('\n');
}

/// Texte compatible avec les polices PDF standard (latin-1) : espaces
/// fines → espaces, « − » → « - », apostrophe courbe → droite…
String pourPdf(String texte) {
  const remplacements = {
    ' ': ' ', ' ': ' ', '−': '-', '–': '-', '—': '-',
    '’': "'", '‘': "'", '“': '"', '”': '"', '…': '...',
    '•': '·', '→': '->', '≈': '~',
  };
  final b = StringBuffer();
  for (final r in texte.runes) {
    final c = String.fromCharCode(r);
    final remplace = remplacements[c];
    if (remplace != null) {
      b.write(remplace);
    } else if (r <= 0xFF) {
      b.write(c);
    }
    // Autres caractères (emoji…) : ignorés.
  }
  return b.toString();
}

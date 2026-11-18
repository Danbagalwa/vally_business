import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/format/dates.dart';
import '../../../core/format/montant.dart';
import '../../../theme/app_theme.dart';
import '../../boutique/domain/boutique.dart';
import '../../ventes/domain/commande.dart';
import '../domain/facture.dart';

/// Couleurs de la charte, converties pour le PDF (aucune couleur en dur).
PdfColor _c(Color couleur) => PdfColor.fromInt(couleur.toARGB32());

/// Teinte claire (couleur mêlée au blanc) : fiable dans tous les lecteurs PDF,
/// contrairement à la transparence.
PdfColor _teinte(PdfColor c, double part) =>
    PdfColor(1 - part * (1 - c.red), 1 - part * (1 - c.green), 1 - part * (1 - c.blue));

final _rose = _c(VallyPalette.rose);
final _roseFonce = _c(VallyPalette.roseDeep);
final _rosePale = _c(VallyPalette.roseSoft);
final _fond = _c(VallyPalette.surface);
final _encre = _c(VallyPalette.ink);
final _gris = _c(VallyPalette.inkMuted);
final _ligne = _c(VallyPalette.line);
final _vert = _c(VallyPalette.benefice);
final _ambre = _c(VallyPalette.attention);

/// Génère la facture PDF d'une vente ou d'une commande (A4, sur le téléphone).
Future<Uint8List> genererFacturePdf({required CommandeDetail detail, required Boutique boutique}) async {
  final titre = pw.Font.ttf(await rootBundle.load('assets/fonts/SpaceGrotesk-Bold.ttf'));
  final logo = pw.MemoryImage((await rootBundle.load('assets/icon/app_icon.png')).buffer.asUint8List());
  final normal = pw.Font.helvetica();
  final gras = pw.Font.helveticaBold();

  final c = detail.commande;
  final devise = boutique.devise;
  String m(num v, {SensMontant sens = SensMontant.neutre}) =>
      pourPdf(FormatMontant.formater(v, devise, sens: sens));
  String t(String s) => pourPdf(s);

  pw.TextStyle st(double taille, {pw.Font? police, PdfColor? couleur, double espacement = 0}) =>
      pw.TextStyle(font: police ?? normal, fontSize: taille, color: couleur ?? _encre, letterSpacing: espacement);

  pw.Widget etiquette(String texte) =>
      pw.Text(texte.toUpperCase(), style: st(7.5, police: gras, couleur: _gris, espacement: 0.8));

  // ─── Statut de paiement (pastille) ───
  final (statutTexte, statutCouleur) = c.annulee
      ? ('Annulée', _gris)
      : switch (c.statutPaiement) {
          StatutPaiement.soldee => ('Payée', _vert),
          StatutPaiement.partiellementPayee => ('Partiellement payée', _ambre),
          StatutPaiement.nonPayee => ('À régler', _ambre),
        };

  pw.Widget pastille() => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: pw.BoxDecoration(
          color: _teinte(statutCouleur, 0.12),
          borderRadius: pw.BorderRadius.circular(20),
        ),
        child: pw.Text(t(statutTexte.toUpperCase()), style: st(8, police: gras, couleur: statutCouleur, espacement: 0.6)),
      );

  pw.Widget carte(String titreCarte, List<pw.Widget> contenu) => pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: _fond,
            borderRadius: pw.BorderRadius.circular(12),
            border: pw.Border.all(color: _ligne, width: 0.8),
          ),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            etiquette(titreCarte),
            pw.SizedBox(height: 6),
            ...contenu,
          ]),
        ),
      );

  // ─── Détails (vente / commande, livraison) ───
  final details = <pw.Widget>[
    pw.Text(c.estCommande ? 'Commande' : 'Vente au comptoir', style: st(11, police: gras)),
    pw.SizedBox(height: 2),
    pw.Text(t('${c.estCommande ? 'Commandée' : 'Vendue'} le ${FormatDate.court(c.date)}'),
        style: st(9, couleur: _gris)),
    if (c.estCommande && c.dateLivraison != null) ...[
      pw.SizedBox(height: 2),
      pw.Text(
          t('${c.modeRemise == ModeRemise.livraison ? 'Livraison' : 'Retrait en boutique'} '
              'le ${FormatDate.court(c.dateLivraison!)}'),
          style: st(9, couleur: _gris)),
      if (c.adresseLivraison != null)
        pw.Text(t(c.adresseLivraison!), style: st(9, couleur: _gris)),
    ],
    pw.SizedBox(height: 8),
    pastille(),
  ];

  // ─── Tableau des articles ───
  pw.Widget cellule(String texte, {bool droite = false, bool entete = false, pw.Font? police}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: pw.Text(
          entete ? texte.toUpperCase() : texte,
          textAlign: droite ? pw.TextAlign.right : pw.TextAlign.left,
          style: entete
              ? st(7.5, police: gras, couleur: _roseFonce, espacement: 0.8)
              : st(10, police: police),
        ),
      );

  final tableau = pw.Table(
    columnWidths: const {
      0: pw.FlexColumnWidth(5),
      1: pw.FixedColumnWidth(44),
      2: pw.FlexColumnWidth(2.2),
      3: pw.FlexColumnWidth(2.4),
    },
    border: pw.TableBorder(horizontalInside: pw.BorderSide(color: _ligne, width: 0.6)),
    children: [
      pw.TableRow(
        decoration: pw.BoxDecoration(color: _rosePale, borderRadius: pw.BorderRadius.circular(8)),
        children: [
          cellule('Article', entete: true),
          cellule('Qté', entete: true, droite: true),
          cellule('Prix unitaire', entete: true, droite: true),
          cellule('Montant', entete: true, droite: true),
        ],
      ),
      for (final l in detail.lignes)
        pw.TableRow(
          verticalAlignment: pw.TableCellVerticalAlignment.middle,
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(t(l.articleNom), style: st(10, police: gras)),
                if (l.articleDescription.isNotEmpty)
                  pw.Text(t(l.articleDescription), style: st(8.5, couleur: _gris)),
              ]),
            ),
            cellule('${l.quantite}', droite: true),
            cellule(m(l.prixVendu), droite: true),
            cellule(m(l.total), droite: true, police: gras),
          ],
        ),
    ],
  );

  // ─── Totaux ───
  pw.Widget ligneTotal(String libelle, String valeur, {PdfColor? couleur, bool fort = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(children: [
          pw.Expanded(child: pw.Text(t(libelle), style: st(9.5, couleur: _gris))),
          pw.Text(valeur, style: st(fort ? 10.5 : 9.5, police: fort ? gras : normal, couleur: couleur)),
        ]),
      );

  final totaux = pw.Container(
    width: 230,
    padding: const pw.EdgeInsets.all(14),
    decoration: pw.BoxDecoration(
      color: _fond,
      borderRadius: pw.BorderRadius.circular(12),
      border: pw.Border.all(color: _ligne, width: 0.8),
    ),
    child: pw.Column(children: [
      ligneTotal('Sous-total', m(c.totalArticles)),
      if (c.fraisLivraison > 0) ligneTotal('Livraison', m(c.fraisLivraison)),
      pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 6), child: pw.Divider(color: _ligne, thickness: 0.8)),
      pw.Row(children: [
        pw.Expanded(child: pw.Text('TOTAL', style: st(9, police: gras, espacement: 0.8))),
        pw.Text(m(c.total), style: st(16, police: titre, couleur: _rose)),
      ]),
      pw.SizedBox(height: 6),
      ligneTotal('Payé', m(c.totalPaye, sens: c.totalPaye > 0 ? SensMontant.positif : SensMontant.neutre),
          couleur: c.totalPaye > 0 ? _vert : null),
      if (!c.annulee && c.resteAPayer > 0)
        ligneTotal('Reste à payer', m(c.resteAPayer, sens: SensMontant.negatif), couleur: _ambre, fort: true),
    ]),
  );

  // ─── Paiements reçus ───
  final paiements = detail.paiements.isEmpty
      ? <pw.Widget>[]
      : <pw.Widget>[
          pw.SizedBox(height: 18),
          etiquette('Paiements reçus'),
          pw.SizedBox(height: 6),
          for (final p in detail.paiements)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Row(children: [
                pw.Expanded(
                  child: pw.Text(
                    t([
                      FormatDate.court(p.date),
                      p.mode.libelle,
                      if (p.converti) '${FormatMontant.formater(p.montantSaisi, p.deviseSaisie)} au taux de ${FormatMontant.formater(p.tauxChange!, Devise.cdf)}',
                    ].join('  ·  ')),
                    style: st(9, couleur: _gris),
                  ),
                ),
                pw.Text(m(p.montant, sens: SensMontant.positif), style: st(9, couleur: _vert)),
              ]),
            ),
        ];

  final doc = pw.Document(
    title: 'Facture ${c.numero ?? ''}',
    author: boutique.nom,
    creator: 'Vally Business',
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 30),
      theme: pw.ThemeData.withFont(base: normal, bold: gras),
      footer: (contexte) => pw.Column(children: [
        pw.Divider(color: _ligne, thickness: 0.6),
        pw.SizedBox(height: 6),
        pw.Text(t('Merci pour ta confiance.'), style: st(12, police: titre, couleur: _rose)),
        pw.SizedBox(height: 2),
        pw.Text(
          t('${boutique.nom}  ·  Facture n° ${c.numero ?? '—'}'
              '${contexte.pagesCount > 1 ? '  ·  Page ${contexte.pageNumber}/${contexte.pagesCount}' : ''}'),
          style: st(7.5, couleur: _gris),
        ),
      ]),
      build: (contexte) => [
        // ─── En-tête ───
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.ClipRRect(
            horizontalRadius: 10,
            verticalRadius: 10,
            child: pw.Image(logo, width: 46, height: 46),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(t(boutique.nom), style: st(20, police: titre)),
              pw.SizedBox(height: 2),
              pw.Text(t(c.estCommande ? 'Bon de commande et facture' : 'Facture de vente'),
                  style: st(9, couleur: _gris)),
            ]),
          ),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('FACTURE', style: st(24, police: titre, couleur: _rose, espacement: 1.5)),
            pw.SizedBox(height: 4),
            pw.Text(t('N° ${c.numero ?? '—'}'), style: st(10, police: gras)),
            pw.Text(t('Date : ${FormatDate.court(c.date)}'), style: st(9, couleur: _gris)),
          ]),
        ]),
        pw.SizedBox(height: 14),
        pw.Container(
          height: 3,
          decoration: pw.BoxDecoration(
            borderRadius: pw.BorderRadius.circular(2),
            gradient: pw.LinearGradient(colors: [_rose, _roseFonce]),
          ),
        ),
        pw.SizedBox(height: 18),

        // ─── Client et détails ───
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          carte('Facturé à', [
            pw.Text(t(c.nomAffiche), style: st(11, police: gras)),
            if (c.clientTelephone != null) ...[
              pw.SizedBox(height: 2),
              pw.Text(t(c.clientTelephone!), style: st(9, couleur: _gris)),
            ],
          ]),
          pw.SizedBox(width: 12),
          carte('Détails', details),
        ]),
        pw.SizedBox(height: 20),

        tableau,
        pw.SizedBox(height: 16),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
            child: c.note == null
                ? pw.SizedBox()
                : pw.Padding(
                    padding: const pw.EdgeInsets.only(right: 16, top: 4),
                    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      etiquette('Note'),
                      pw.SizedBox(height: 4),
                      pw.Text(t(c.note!), style: st(9, couleur: _gris)),
                    ]),
                  ),
          ),
          totaux,
        ]),
        ...paiements,
      ],
    ),
  );

  return doc.save();
}

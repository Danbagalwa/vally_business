import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vally_business/core/format/dates.dart';
import 'package:vally_business/core/format/montant.dart';
import 'package:vally_business/features/accueil/domain/resume_jour.dart';
import 'package:vally_business/features/ventes/domain/commande.dart';

import '../ventes/donnees_ventes.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  group('Phrase du jour', () {
    test('ventes et commandes', () {
      expect(phraseDuJour(ventes: 3, taches: 2),
          'Tu as déjà fait 3 ventes aujourd’hui, et 2 commandes t’attendent.');
      expect(phraseDuJour(ventes: 1, taches: 1),
          'Tu as déjà fait 1 vente aujourd’hui, et 1 commande t’attend.');
    });

    test('rien encore', () {
      expect(phraseDuJour(ventes: 0, taches: 0),
          'Pas encore de vente aujourd’hui, et aucune commande ne t’attend.');
      expect(phraseDuJour(ventes: 0, taches: 2),
          'Pas encore de vente aujourd’hui, mais 2 commandes t’attendent.');
      expect(phraseDuJour(ventes: 4, taches: 0),
          'Tu as déjà fait 4 ventes aujourd’hui. Aucune commande ne t’attend.');
    });

    test('jamais de point d’exclamation (charte)', () {
      for (final v in [0, 1, 5]) {
        for (final t in [0, 1, 3]) {
          expect(phraseDuJour(ventes: v, taches: t), isNot(contains('!')));
        }
      }
    });
  });

  test('salutation selon l’heure', () {
    expect(salutation(DateTime(2026, 11, 21, 8)), 'Bonjour');
    expect(salutation(DateTime(2026, 11, 21, 14)), 'Bon après-midi');
    expect(salutation(DateTime(2026, 11, 21, 19)), 'Bonsoir');
  });

  test('ventes des 7 derniers jours : aujourd’hui en dernier, jours vides à 0', () {
    Commande vente(String date, num total, {bool annulee = false}) => Commande.fromJson(ligneVCommandes(
          date: date,
          total: total,
          statutLivraison: annulee ? 'annulee' : 'livree',
        ));
    final points = ventesParJour([
      vente('2026-11-21', 45000),
      vente('2026-11-21', 18000),
      vente('2026-11-19', 15000),
      vente('2026-11-19', 99000, annulee: true),
      vente('2026-11-10', 50000), // trop ancien
    ], aujourdhui: DateTime(2026, 11, 21, 10));
    expect(points.length, 7);
    expect(points.first.$1, DateTime(2026, 11, 15));
    expect(points.last.$1, DateTime(2026, 11, 21));
    expect(points.last.$2, 63000);
    expect(points[4].$2, 15000); // 19 nov., l'annulée ne compte pas
    expect(points[5].$2, 0);
  });

  test('tâche écrite avec un verbe selon l’état de la commande', () {
    Commande commande(String statut, String mode) => Commande.fromJson(ligneVCommandes(
          type: 'commande',
          clientNom: 'Mme Kabila',
          statutLivraison: statut,
          dateLivraison: '2026-11-21',
          modeRemise: mode,
        ));
    expect(tacheCommande(commande('en_attente', 'livraison')), 'Préparer la commande de Mme Kabila');
    expect(tacheCommande(commande('prete', 'livraison')), 'Livrer Mme Kabila');
    expect(tacheCommande(commande('prete', 'retrait')), 'Remettre la commande à Mme Kabila');
  });

  test('il y a… : aujourd’hui, hier, il y a 3 jours, le 12 nov.', () {
    final a = DateTime(2026, 11, 21);
    expect(FormatDate.ilYa(DateTime(2026, 11, 21, 9), aujourdhui: a), 'aujourd’hui');
    expect(FormatDate.ilYa(DateTime(2026, 11, 20), aujourdhui: a), 'hier');
    expect(FormatDate.ilYa(DateTime(2026, 11, 18), aujourdhui: a), 'il y a 3 jours');
    expect(FormatDate.ilYa(DateTime(2026, 11, 2), aujourdhui: a), 'le 2 nov.');
    expect(FormatDate.ilYa(DateTime(2025, 12, 24), aujourdhui: a), 'le 24 déc. 2025');
  });

  test('montant sans devise pour le grand chiffre', () {
    expect(FormatMontant.nombre(95000, Devise.cdf), '95 000');
    expect(FormatMontant.nombre(-12.5, Devise.usd), '12,50');
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vally_business/core/rayon.dart';
import 'package:vally_business/features/clients/domain/client_resume.dart';
import 'package:vally_business/features/stock/data/stock_repository.dart';
import 'package:vally_business/features/stock/domain/article.dart';
import 'package:vally_business/features/ventes/data/ventes_repository.dart';
import 'package:vally_business/features/ventes/domain/commande.dart';

import 'stock/donnees.dart';
import 'ventes/donnees_ventes.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('rayon lu de la base ; absent (base pas à jour) = habits', () {
    expect(Article.fromJson(ligneVStock()..['rayon'] = 'parfums').rayon, Rayon.parfums);
    expect(Article.fromJson(ligneVStock()).rayon, Rayon.habits);
    expect(Commande.fromJson(ligneVCommandes()..['rayon'] = 'parfums').rayon, Rayon.parfums);
    expect(Commande.fromJson(ligneVCommandes()).rayon, Rayon.habits);
  });

  test('un nouvel article enregistre son rayon', () {
    final json = ArticleSaisie(
      nom: 'Oud royal', categorie: 'Parfum', taille: '100 ml', quantiteAchetee: 5,
      prixAchat: 20000, prixVenteHabituel: 35000, dateAppro: DateTime(2026, 11, 25),
      rayon: Rayon.parfums,
    ).toJson();
    expect(json['rayon'], 'parfums');
  });

  test('dette d’un client, rayon par rayon', () {
    final c = ClientResume.fromJson({
      'id': 'c', 'nom': 'Mme Kabila', 'nb_achats': 2, 'total_achats': 100000,
      'total_du': 50000, 'nb_impayes': 2, 'du_habits': 15000, 'du_parfums': 35000,
    });
    expect(c.duPour(Rayon.habits), 15000);
    expect(c.duPour(Rayon.parfums), 35000);
    // Base pas encore à jour : toute la dette est en habits.
    final ancien = ClientResume.fromJson({
      'id': 'c', 'nom': 'X', 'nb_achats': 1, 'total_achats': 9000, 'total_du': 9000, 'nb_impayes': 1,
    });
    expect(ancien.duPour(Rayon.habits), 9000);
    expect(ancien.duPour(Rayon.parfums), 0);
  });

  test('les listes ne montrent que le rayon choisi', () async {
    final conteneur = ProviderContainer(overrides: [
      commandesProvider.overrideWith((ref) async => [
            Commande.fromJson(ligneVCommandes(id: 'h')),
            Commande.fromJson(ligneVCommandes(id: 'p')..['rayon'] = 'parfums'),
          ]),
      articlesProvider.overrideWith((ref) async => [
            article(nom: 'Robe'),
            Article.fromJson(ligneVStock(nom: 'Oud royal')..['rayon'] = 'parfums'),
          ]),
    ]);
    addTearDown(conteneur.dispose);
    await conteneur.read(commandesProvider.future);
    await conteneur.read(articlesProvider.future);

    expect(conteneur.read(commandesRayonProvider).value!.map((c) => c.id), ['h']);
    expect(conteneur.read(articlesRayonProvider).value!.map((a) => a.nom), ['Robe']);

    await conteneur.read(rayonProvider.notifier).choisir(Rayon.parfums);
    expect(conteneur.read(commandesRayonProvider).value!.map((c) => c.id), ['p']);
    expect(conteneur.read(articlesRayonProvider).value!.map((a) => a.nom), ['Oud royal']);
  });
}

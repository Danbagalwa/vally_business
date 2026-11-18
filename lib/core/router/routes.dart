/// Chemins de l'application.
abstract final class Routes {
  static const connexion = '/connexion';

  // Onglets
  static const accueil = '/accueil';
  static const ventes = '/ventes';
  static const commandes = '/commandes';
  static const stock = '/stock';
  static const plus = '/plus';

  // Ventes et commandes
  static const nouvelleVente = '/ventes/nouvelle';
  static String vente(String id) => '/ventes/$id';
  static const nouvelleCommande = '/commandes/nouvelle';
  static String commande(String id) => '/commandes/$id';

  // Stock
  static const nouvelArticle = '/stock/nouveau';
  static String article(String id) => '/stock/$id';

  // Écrans ouverts depuis « Plus » ou l'accueil
  static const clients = '/clients';
  static String client(String id) => '/clients/$id';
  static const statistiques = '/statistiques';
  static const depenses = '/depenses';
  static const maBoutique = '/boutique';
  static const calculateur = '/calculateur';
}

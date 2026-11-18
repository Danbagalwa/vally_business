/// Chemins de l'application.
abstract final class Routes {
  static const connexion = '/connexion';
  static const stock = '/stock';
  static const nouvelArticle = '/stock/nouveau';
  static String article(String id) => '/stock/$id';
  static const ventes = '/ventes';
  static const nouvelleVente = '/ventes/nouvelle';
  static String commande(String id) => '/ventes/$id';
  static const tableauDeBord = '/tableau-de-bord';
  static const depenses = '/depenses';
  static const maBoutique = '/boutique';
}

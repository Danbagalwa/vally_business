/// Petits outils de texte à la française.
library;

/// Espace insécable : garde ensemble « 2 » et « pièces », « 2 » et « × ».
final espaceInsecable = String.fromCharCode(0xA0);

/// « 1 pièce », « 2 pièces » : le nombre et le mot restent sur la même ligne.
String pieces(int n) => '$n${espaceInsecable}pièce${n > 1 ? 's' : ''}';

/// Texte comparable pour une recherche : minuscules, sans accents
/// (« Soirée » et « soiree » se retrouvent).
String normaliserRecherche(String texte) {
  const accents = {
    'à': 'a', 'â': 'a', 'ä': 'a', 'ç': 'c', 'é': 'e', 'è': 'e', 'ê': 'e',
    'ë': 'e', 'î': 'i', 'ï': 'i', 'ô': 'o', 'ö': 'o', 'ù': 'u', 'û': 'u',
    'ü': 'u', 'ÿ': 'y', 'œ': 'oe',
  };
  final bas = texte.toLowerCase();
  final sortie = StringBuffer();
  for (final c in bas.split('')) {
    sortie.write(accents[c] ?? c);
  }
  return sortie.toString();
}

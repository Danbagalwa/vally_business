/// Calcul simple saisi au clavier : « 25*3 », « 120 000 + 35 000 »,
/// « 15,5 × 2 », « 90000 / 3 - 500 ».
/// Gère + − × ÷ (aussi * / x), les priorités (× ÷ avant + −) et la virgule
/// décimale. Retourne null si la saisie est vide ou invalide.
double? evaluerCalcul(String saisie) {
  final propre = saisie
      .replaceAll(RegExp(r'[\s  ]'), '')
      .replaceAll(',', '.')
      .replaceAll('×', '*')
      .replaceAll('x', '*')
      .replaceAll('X', '*')
      .replaceAll('÷', '/')
      .replaceAll('−', '-');
  if (propre.isEmpty) return null;

  // Découpe en nombres et opérateurs ; un « - » en tête ou après un
  // opérateur appartient au nombre qui suit.
  final jetons = <String>[];
  var nombre = StringBuffer();
  for (var i = 0; i < propre.length; i++) {
    final c = propre[i];
    final estOperateur = '+-*/'.contains(c);
    final signe = c == '-' && (jetons.isEmpty && nombre.isEmpty ||
        (nombre.isEmpty && jetons.isNotEmpty && '+-*/'.contains(jetons.last)));
    if (estOperateur && !signe) {
      if (nombre.isEmpty) return null;
      jetons..add(nombre.toString())..add(c);
      nombre = StringBuffer();
    } else {
      nombre.write(c);
    }
  }
  if (nombre.isEmpty) return null;
  jetons.add(nombre.toString());

  // 1) × et ÷  2) + et −
  final termes = <double>[];
  final signes = <String>['+'];
  double? courant = double.tryParse(jetons[0]);
  if (courant == null) return null;
  for (var i = 1; i < jetons.length; i += 2) {
    final op = jetons[i];
    final v = double.tryParse(jetons[i + 1]);
    if (v == null) return null;
    switch (op) {
      case '*':
        courant = courant! * v;
      case '/':
        if (v == 0) return null;
        courant = courant! / v;
      default:
        termes.add(courant!);
        signes.add(op);
        courant = v;
    }
  }
  termes.add(courant!);
  var total = 0.0;
  for (var i = 0; i < termes.length; i++) {
    total += signes[i] == '-' ? -termes[i] : termes[i];
  }
  return total;
}

/// Vrai si la saisie contient une opération (et pas seulement un nombre).
bool estUnCalcul(String saisie) =>
    RegExp(r'\d\s*[+\-*/×÷xX−]\s*-?\d').hasMatch(saisie.replaceAll(',', '.'));

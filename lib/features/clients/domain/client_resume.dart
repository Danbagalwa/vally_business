import '../../../core/format/dates.dart';

double _n(Object? v) => (v as num?)?.toDouble() ?? 0;

/// Client avec ses achats et sa dette (vue v_clients).
class ClientResume {
  const ClientResume({
    required this.id,
    required this.nom,
    this.telephone,
    required this.nbAchats,
    required this.totalAchats,
    required this.totalDu,
    required this.nbImpayes,
    this.dernierAchat,
  });

  final String id;
  final String nom;
  final String? telephone;
  final int nbAchats;
  final double totalAchats;

  /// Ce que le client doit encore (ventes et commandes non annulées).
  final double totalDu;
  final int nbImpayes;
  final DateTime? dernierAchat;

  bool get doit => totalDu > 0;

  /// Initiales pour l'avatar : « Maman Rose » → « MR ».
  String get initiales {
    final mots = nom.trim().split(RegExp(r'\s+')).where((m) => m.isNotEmpty);
    return mots.take(2).map((m) => m[0].toUpperCase()).join();
  }

  factory ClientResume.fromJson(Map<String, dynamic> j) => ClientResume(
        id: j['id'] as String,
        nom: j['nom'] as String,
        telephone: j['telephone'] as String?,
        nbAchats: (j['nb_achats'] as num?)?.toInt() ?? 0,
        totalAchats: _n(j['total_achats']),
        totalDu: _n(j['total_du']),
        nbImpayes: (j['nb_impayes'] as num?)?.toInt() ?? 0,
        dernierAchat: j['dernier_achat'] == null
            ? null
            : FormatDate.lire(j['dernier_achat'] as String),
      );
}

enum FiltreClients {
  tous('Tous'),
  meDoivent('Me doivent');

  const FiltreClients(this.libelle);

  final String libelle;
}

/// Recherche (nom, téléphone) ; « Me doivent » trié par dette décroissante.
List<ClientResume> filtrerClients(
  List<ClientResume> clients, {
  FiltreClients filtre = FiltreClients.tous,
  String recherche = '',
}) {
  final r = recherche.trim().toLowerCase();
  final chiffres = r.replaceAll(RegExp(r'\D'), '');
  final liste = clients.where((c) {
    if (filtre == FiltreClients.meDoivent && !c.doit) return false;
    if (r.isEmpty) return true;
    return c.nom.toLowerCase().contains(r) ||
        (chiffres.isNotEmpty &&
            (c.telephone ?? '').replaceAll(RegExp(r'\D'), '').contains(chiffres));
  }).toList();
  if (filtre == FiltreClients.meDoivent) {
    liste.sort((a, b) => b.totalDu.compareTo(a.totalDu));
  }
  return liste;
}

/// Numéro pour WhatsApp (wa.me) : chiffres seulement, indicatif RDC (243)
/// ajouté si le numéro commence par 0.
String? numeroWhatsApp(String? telephone) {
  if (telephone == null) return null;
  var n = telephone.replaceAll(RegExp(r'\D'), '');
  if (n.isEmpty) return null;
  if (n.startsWith('00')) n = n.substring(2);
  if (n.startsWith('0')) n = '243${n.substring(1)}';
  return n;
}

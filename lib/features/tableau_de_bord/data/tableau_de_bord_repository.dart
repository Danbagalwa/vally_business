import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/format/dates.dart';
import '../../../core/rayon.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../depenses/data/depenses_repository.dart';
import '../../stock/data/stock_repository.dart';
import '../../ventes/data/ventes_repository.dart';
import '../domain/indicateurs.dart';
import '../domain/periode.dart';

/// Lecture des indicateurs (fonctions SQL et vue v_dashboard).
class TableauDeBordRepository {
  TableauDeBordRepository(this._client);

  final SupabaseClient _client;

  Map<String, dynamic> _bornes(Periode p, Rayon r) => {
        'p_debut': FormatDate.iso(p.debut),
        'p_fin': FormatDate.iso(p.fin),
        'p_rayon': r.code,
      };

  Future<IndicateursPeriode> periode(Periode p, Rayon r) async {
    final lignes = await _client.rpc('dashboard_periode', params: _bornes(p, r))
        as List<dynamic>;
    return IndicateursPeriode.fromJson(lignes.first as Map<String, dynamic>);
  }

  /// Les deux rayons ensemble (Mes dépenses : « Me verser un bénéfice »).
  Future<IndicateursActuels> actuels() async {
    final ligne = await _client.from('v_dashboard').select().maybeSingle();
    return ligne == null ? IndicateursActuels.vide : IndicateursActuels.fromJson(ligne);
  }

  /// Un seul rayon (Statistiques). Versé et disponible y restent communs.
  Future<IndicateursActuels> actuelsRayon(Rayon r) async {
    final ligne = await _client.from('v_dashboard_rayon').select().eq('rayon', r.code).maybeSingle();
    return ligne == null ? IndicateursActuels.vide : IndicateursActuels.fromJson(ligne);
  }

  Future<List<ArticleVendu>> articlesVendus(Periode p, Rayon r) async {
    final lignes =
        await _client.rpc('articles_vendus_periode', params: _bornes(p, r))
            as List<dynamic>;
    return lignes
        .map((l) => ArticleVendu.fromJson(l as Map<String, dynamic>))
        .toList();
  }
}

final tableauDeBordRepositoryProvider = Provider<TableauDeBordRepository>(
  (ref) => TableauDeBordRepository(ref.watch(supabaseClientProvider)),
);

/// Période choisie (par défaut : ce mois).
class PeriodeNotifier extends Notifier<Periode> {
  @override
  Periode build() => Periode.de(TypePeriode.ceMois);

  void choisir(Periode periode) => state = periode;
}

final periodeProvider =
    NotifierProvider<PeriodeNotifier, Periode>(PeriodeNotifier.new);

/// Les indicateurs se rechargent quand les ventes ou le stock changent
/// (ces providers sont invalidés après chaque enregistrement).
Future<void> _suivreVentesEtStock(Ref ref) async {
  await ref.watch(commandesProvider.future);
  await ref.watch(articlesProvider.future);
}

final indicateursPeriodeProvider =
    FutureProvider.autoDispose<IndicateursPeriode>((ref) async {
  final periode = ref.watch(periodeProvider);
  await _suivreVentesEtStock(ref);
  return ref.watch(tableauDeBordRepositoryProvider).periode(periode, ref.watch(rayonProvider));
});

final indicateursActuelsProvider =
    FutureProvider.autoDispose<IndicateursActuels>((ref) async {
  await _suivreVentesEtStock(ref);
  // Le bénéfice disponible baisse à chaque versement dans Mes dépenses.
  await ref.watch(mouvementsProvider.future);
  return ref.watch(tableauDeBordRepositoryProvider).actuels();
});

/// Indicateurs actuels du rayon affiché (Statistiques).
final indicateursRayonProvider = FutureProvider.autoDispose<IndicateursActuels>((ref) async {
  await _suivreVentesEtStock(ref);
  await ref.watch(mouvementsProvider.future);
  return ref.watch(tableauDeBordRepositoryProvider).actuelsRayon(ref.watch(rayonProvider));
});

final articlesVendusProvider =
    FutureProvider.autoDispose<List<ArticleVendu>>((ref) async {
  final periode = ref.watch(periodeProvider);
  await _suivreVentesEtStock(ref);
  return ref.watch(tableauDeBordRepositoryProvider).articlesVendus(periode, ref.watch(rayonProvider));
});

/// Mêmes indicateurs sur la période de comparaison (voir Periode.precedente).
final indicateursPrecedentsProvider =
    FutureProvider.autoDispose<IndicateursPeriode>((ref) async {
  final periode = ref.watch(periodeProvider).precedente();
  await _suivreVentesEtStock(ref);
  return ref.watch(tableauDeBordRepositoryProvider).periode(periode, ref.watch(rayonProvider));
});

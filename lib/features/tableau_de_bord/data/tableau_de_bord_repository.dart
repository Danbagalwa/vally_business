import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/format/dates.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../stock/data/stock_repository.dart';
import '../../ventes/data/ventes_repository.dart';
import '../domain/indicateurs.dart';
import '../domain/periode.dart';

/// Lecture des indicateurs (fonctions SQL et vue v_dashboard).
class TableauDeBordRepository {
  TableauDeBordRepository(this._client);

  final SupabaseClient _client;

  Map<String, dynamic> _bornes(Periode p) => {
        'p_debut': FormatDate.iso(p.debut),
        'p_fin': FormatDate.iso(p.fin),
      };

  Future<IndicateursPeriode> periode(Periode p) async {
    final lignes = await _client.rpc('dashboard_periode', params: _bornes(p))
        as List<dynamic>;
    return IndicateursPeriode.fromJson(lignes.first as Map<String, dynamic>);
  }

  Future<IndicateursActuels> actuels() async {
    final ligne = await _client.from('v_dashboard').select().maybeSingle();
    return ligne == null
        ? IndicateursActuels.vide
        : IndicateursActuels.fromJson(ligne);
  }

  Future<List<ArticleVendu>> articlesVendus(Periode p) async {
    final lignes =
        await _client.rpc('articles_vendus_periode', params: _bornes(p))
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
  return ref.watch(tableauDeBordRepositoryProvider).periode(periode);
});

final indicateursActuelsProvider =
    FutureProvider.autoDispose<IndicateursActuels>((ref) async {
  await _suivreVentesEtStock(ref);
  return ref.watch(tableauDeBordRepositoryProvider).actuels();
});

final articlesVendusProvider =
    FutureProvider.autoDispose<List<ArticleVendu>>((ref) async {
  final periode = ref.watch(periodeProvider);
  await _suivreVentesEtStock(ref);
  return ref.watch(tableauDeBordRepositoryProvider).articlesVendus(periode);
});

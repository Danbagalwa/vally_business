import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/connexion_page.dart';
import '../../features/depenses/presentation/depenses_page.dart';
import '../../features/stock/presentation/stock_page.dart';
import '../../features/tableau_de_bord/presentation/tableau_de_bord_page.dart';
import '../../features/ventes/presentation/ventes_page.dart';
import 'coquille_onglets.dart';

/// Chemins de l'application.
abstract final class Routes {
  static const connexion = '/connexion';
  static const stock = '/stock';
  static const ventes = '/ventes';
  static const tableauDeBord = '/tableau-de-bord';
  static const depenses = '/depenses';
}

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  final rafraichir = _RafraichirSurFlux(auth.changements);
  ref.onDispose(rafraichir.dispose);

  final router = GoRouter(
    initialLocation: Routes.stock,
    refreshListenable: rafraichir,
    redirect: (context, state) {
      final surConnexion = state.matchedLocation == Routes.connexion;
      if (!auth.estConnecte) return surConnexion ? null : Routes.connexion;
      if (surConnexion) return Routes.stock;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.connexion,
        builder: (context, state) => const ConnexionPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            CoquilleOnglets(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.stock,
              builder: (context, state) => const StockPage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.ventes,
              builder: (context, state) => const VentesPage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.tableauDeBord,
              builder: (context, state) => const TableauDeBordPage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.depenses,
              builder: (context, state) => const DepensesPage(),
            ),
          ]),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

/// Relance la redirection du routeur à chaque connexion / déconnexion.
class _RafraichirSurFlux extends ChangeNotifier {
  _RafraichirSurFlux(Stream<dynamic> flux) {
    _abonnement = flux.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _abonnement;

  @override
  void dispose() {
    _abonnement.cancel();
    super.dispose();
  }
}

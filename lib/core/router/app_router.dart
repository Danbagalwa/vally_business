import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/accueil/presentation/accueil_page.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/connexion_page.dart';
import '../../features/boutique/presentation/ma_boutique_page.dart';
import '../../features/boutique/presentation/porte_boutique.dart';
import '../../features/clients/domain/client_resume.dart';
import '../../features/clients/presentation/client_detail_page.dart';
import '../../features/clients/presentation/clients_page.dart';
import '../../features/depenses/presentation/depenses_page.dart';
import '../../features/plus/presentation/plus_page.dart';
import '../../features/stock/presentation/article_form_page.dart';
import '../../features/stock/presentation/stock_page.dart';
import '../../features/tableau_de_bord/presentation/tableau_de_bord_page.dart';
import '../../features/ventes/domain/commande.dart';
import '../../features/ventes/presentation/commande_detail_page.dart';
import '../../features/ventes/presentation/commandes_page.dart';
import '../../features/ventes/presentation/saisie_vente_page.dart';
import '../../features/ventes/presentation/ventes_page.dart';
import 'coquille_onglets.dart';
import 'routes.dart';

export 'routes.dart';

final _racineKey = GlobalKey<NavigatorState>(debugLabel: 'racine');

/// Écran plein écran (sans barre d'onglets), derrière la PorteBoutique.
GoRoute _pleinEcran(String path, Widget Function(GoRouterState) page) => GoRoute(
      path: path,
      parentNavigatorKey: _racineKey,
      builder: (context, state) => PorteBoutique(child: page(state)),
    );

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  final rafraichir = _RafraichirSurFlux(auth.changements);
  ref.onDispose(rafraichir.dispose);

  final router = GoRouter(
    navigatorKey: _racineKey,
    initialLocation: Routes.accueil,
    refreshListenable: rafraichir,
    redirect: (context, state) {
      final surConnexion = state.matchedLocation == Routes.connexion;
      if (!auth.estConnecte) return surConnexion ? null : Routes.connexion;
      if (surConnexion) return Routes.accueil;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.connexion,
        builder: (context, state) => const ConnexionPage(),
      ),
      _pleinEcran(Routes.maBoutique, (_) => const MaBoutiquePage()),
      _pleinEcran(Routes.statistiques, (_) => const TableauDeBordPage()),
      _pleinEcran(Routes.depenses, (_) => const DepensesPage()),
      _pleinEcran(
        Routes.clients,
        (s) => ClientsPage(
          filtreInitial: s.uri.queryParameters['filtre'] == 'dettes'
              ? FiltreClients.meDoivent
              : FiltreClients.tous,
        ),
      ),
      _pleinEcran('${Routes.clients}/:id',
          (s) => ClientDetailPage(clientId: s.pathParameters['id']!)),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            PorteBoutique(child: CoquilleOnglets(navigationShell: shell)),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.accueil, builder: (_, _) => const AccueilPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.ventes,
              builder: (_, _) => const VentesPage(),
              routes: [
                _pleinEcran('nouvelle', (_) => const SaisieVentePage(type: TypeCommande.vente)),
                _pleinEcran(':id', (s) => CommandeDetailPage(commandeId: s.pathParameters['id']!)),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.commandes,
              builder: (_, _) => const CommandesPage(),
              routes: [
                _pleinEcran('nouvelle', (_) => const SaisieVentePage(type: TypeCommande.commande)),
                _pleinEcran(':id', (s) => CommandeDetailPage(commandeId: s.pathParameters['id']!)),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.stock,
              builder: (_, _) => const StockPage(),
              routes: [
                _pleinEcran('nouveau', (_) => const ArticleFormPage()),
                _pleinEcran(':id', (s) => ArticleFormPage(articleId: s.pathParameters['id'])),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.plus, builder: (_, _) => const PlusPage()),
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

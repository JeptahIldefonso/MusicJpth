import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/home/home_screen.dart';
import '../features/library/album_detail_screen.dart';
import '../features/library/artist_detail_screen.dart';
import '../features/library/browse_models.dart';
import '../features/library/library_screen.dart'
    show LibraryScreen, LibrarySongList;
import '../features/player/full_player_screen.dart';
import '../features/playlists/playlists_screen.dart'
    show PlaylistsScreen, PlaylistDetailScreen;
import '../features/search/search_screen.dart';
import '../features/settings/settings_screen.dart';
import 'shell.dart';

/// Route paths.
abstract final class AppRoutes {
  const AppRoutes._();

  static const String home = '/';
  static const String library = '/library';
  static const String librarySongs = '/library/songs';
  static const String libraryAlbum = '/library/album';
  static const String libraryArtist = '/library/artist';
  static const String search = '/search';
  static const String playlists = '/playlists';
  static const String settings = '/settings';
  static const String player = '/player';
}

/// Branch order: 0 = HOME, 1 = SEARCH, 2 = LIBRARY, 3 = PLAYLISTS.
abstract final class AppBranch {
  const AppBranch._();

  static const int home = 0;
  static const int search = 1;
  static const int library = 2;
  static const int playlists = 3;
}

final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  final GoRouter router = GoRouter(
    initialLocation: AppRoutes.home,
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (
          BuildContext context,
          GoRouterState state,
          StatefulNavigationShell navigationShell,
        ) => AppShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.home,
                builder: (BuildContext context, GoRouterState state) =>
                    const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.search,
                builder: (BuildContext context, GoRouterState state) =>
                    const SearchScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.library,
                builder: (BuildContext context, GoRouterState state) =>
                    const LibraryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.playlists,
                builder: (BuildContext context, GoRouterState state) =>
                    const PlaylistsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.player,
        builder: (BuildContext context, GoRouterState state) =>
            const FullPlayerScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.playlists}/:id',
        builder: (BuildContext context, GoRouterState state) =>
            PlaylistDetailScreen(
              playlistId: int.parse(state.pathParameters['id']!),
            ),
      ),
      GoRoute(
        path: AppRoutes.librarySongs,
        builder: (BuildContext context, GoRouterState state) =>
            const LibrarySongList(),
      ),
      GoRoute(
        path: AppRoutes.libraryAlbum,
        builder: (BuildContext context, GoRouterState state) =>
            AlbumDetailScreen(album: state.extra! as AlbumItem),
      ),
      GoRoute(
        path: AppRoutes.libraryArtist,
        builder: (BuildContext context, GoRouterState state) =>
            ArtistDetailScreen(artist: state.extra! as ArtistItem),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (BuildContext context, GoRouterState state) =>
            const SettingsScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

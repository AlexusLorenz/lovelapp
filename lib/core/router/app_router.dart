import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/chat/chat_list_screen.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/discover/discover_screen.dart';
import '../../features/games/games_screen.dart';
import '../../features/games/this_or_that/this_or_that_screen.dart';
import '../../features/matches/matches_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../widgets/app_shell.dart';

class Routes {
  const Routes._();

  static const discover = '/discover';
  static const matches = '/matches';
  static const chats = '/chats';
  static const profile = '/profile';
  static const games = '/games';

  static String chat(String matchId) => '$chats/$matchId';
  static String game(String gameKey) => '$games/$gameKey';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.discover,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.discover,
                builder: (context, state) => const DiscoverScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.matches,
                builder: (context, state) => const MatchesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.chats,
                builder: (context, state) => const ChatListScreen(),
                routes: [
                  GoRoute(
                    path: ':matchId',
                    builder: (context, state) =>
                        ChatScreen(matchId: state.pathParameters['matchId']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: Routes.games,
        builder: (context, state) => const GamesScreen(),
        routes: [
          GoRoute(
            path: 'this_or_that',
            builder: (context, state) => const ThisOrThatScreen(),
          ),
        ],
      ),
    ],
  );
});

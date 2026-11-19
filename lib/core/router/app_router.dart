import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/moderation/moderation_screen.dart';
import '../../features/auth/sign_in_screen.dart';
import '../../features/auth/sign_up_screen.dart';
import '../../features/auth/welcome_screen.dart';
import '../../features/legal/legal_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/session/session_controller.dart';
import '../../features/session/splash_screen.dart';
import '../../features/chat/chat_list_screen.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/discover/discover_screen.dart';
import '../../features/discover/profile_detail_screen.dart';
import '../../features/games/games_screen.dart';
import '../../features/quiz/quiz_game_screen.dart';
import '../../features/quiz/quiz_play_screen.dart';
import '../../features/games/this_or_that/this_or_that_screen.dart';
import '../../features/likes/likes_screen.dart';
import '../../features/account/account_providers.dart';
import '../../features/account/change_password_screen.dart';
import '../../features/interests/game_picker_screen.dart';
import '../../features/interests/interest_picker_screen.dart';
import '../../features/music/music_picker_screen.dart';
import '../../features/profile/edit_profile_screen.dart';
import '../../features/profile/own_preview_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../widgets/app_shell.dart';

class Routes {
  const Routes._();

  static const discover = '/discover';
  static const likes = '/likes';
  static const chats = '/chats';
  static const profile = '/profile';
  static const games = '/games';
  static const editProfile = '/profile/edit';
  static const editInterests = '/profile/interests';
  static const editGames = '/profile/games';

  /// Fest in web/spotify-callback.html eingetragen.
  static const editMusic = '/profile/music';
  static const ownPreview = '/me';
  static const changePassword = '/account/password';
  static const moderation = '/moderation';

  static const splash = '/splash';
  static const welcome = '/welcome';
  static const signIn = '/auth/sign-in';
  static const signUp = '/auth/sign-up';
  static const onboarding = '/onboarding';
  static const privacy = '/legal/privacy';
  static const terms = '/legal/terms';

  static String chat(String matchId) => '$chats/$matchId';
  static String person(String id, {bool withActions = false}) =>
      '/people/$id${withActions ? '?actions=1' : ''}';
  static String game(String gameKey) => '$games/$gameKey';
  static String quizGame(String id) => '$games/quiz/$id';
  static String quizPlay(String id) => '/play/quiz/$id';
}

/// Wohin gehört man je nach Sitzungsstand? `null` = bleiben.
String? redirectFor(SessionStatus status, String location) {
  final isAuthPage =
      location == Routes.welcome || location.startsWith('/auth/');
  if (location.startsWith('/legal/')) return null; // immer erreichbar
  switch (status) {
    case SessionStatus.loading:
    case SessionStatus.error:
      return location == Routes.splash ? null : Routes.splash;
    case SessionStatus.signedOut:
      return isAuthPage ? null : Routes.welcome;
    case SessionStatus.needsProfile:
      return location == Routes.onboarding ? null : Routes.onboarding;
    case SessionStatus.ready:
      final outsideApp =
          isAuthPage ||
          location == Routes.onboarding ||
          location == Routes.splash;
      return outsideApp ? Routes.discover : null;
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  // Bei jeder Änderung der Sitzung prüft der Router die Weiterleitung neu.
  final refresh = ValueNotifier(0);
  ref
    ..listen(sessionProvider, (_, _) => refresh.value++)
    ..listen(passwordRecoveryProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.discover,
    refreshListenable: refresh,
    redirect: (context, state) {
      final status = ref.read(sessionProvider).status;
      // Über einen Passwort-Link gekommen → zuerst neues Passwort.
      if (status == SessionStatus.ready &&
          ref.read(passwordRecoveryProvider) &&
          state.matchedLocation != Routes.changePassword) {
        return Routes.changePassword;
      }
      return redirectFor(status, state.matchedLocation);
    },
    routes: [
      GoRoute(
        path: Routes.changePassword,
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: Routes.signIn,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: Routes.signUp,
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: Routes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/legal/:doc',
        builder: (context, state) =>
            LegalScreen(doc: state.pathParameters['doc']!),
      ),
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
                path: Routes.likes,
                builder: (context, state) => const LikesScreen(),
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
                path: Routes.games,
                builder: (context, state) => const GamesScreen(),
                routes: [
                  GoRoute(
                    path: 'quiz/:id',
                    builder: (context, state) =>
                        QuizGameScreen(gameId: state.pathParameters['id']!),
                  ),
                  GoRoute(
                    path: 'this_or_that',
                    builder: (context, state) => const ThisOrThatScreen(),
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
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) => const EditProfileScreen(),
                  ),
                  GoRoute(
                    path: 'interests',
                    builder: (context, state) => const InterestPickerScreen(),
                  ),
                  GoRoute(
                    path: 'games',
                    builder: (context, state) => const GamePickerScreen(),
                  ),
                  GoRoute(
                    path: 'music',
                    builder: (context, state) => const MusicPickerScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: Routes.ownPreview,
        pageBuilder: (context, state) => const MaterialPage(
          fullscreenDialog: true,
          child: OwnPreviewScreen(),
        ),
      ),
      GoRoute(
        path: '/people/:id',
        pageBuilder: (context, state) => MaterialPage(
          fullscreenDialog: true,
          child: ProfileDetailScreen(
            profileId: state.pathParameters['id']!,
            showActions: state.uri.queryParameters['actions'] == '1',
          ),
        ),
      ),
      GoRoute(
        path: Routes.moderation,
        builder: (context, state) => const ModerationScreen(),
      ),
      // Spielen ohne Tab-Leiste, damit nichts ablenkt.
      GoRoute(
        path: '/play/quiz/:id',
        pageBuilder: (context, state) => MaterialPage(
          fullscreenDialog: true,
          child: QuizPlayScreen(gameId: state.pathParameters['id']!),
        ),
      ),
    ],
  );
});

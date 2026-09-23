import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/screens/auth_choice_screen.dart';
import '../../features/auth/presentation/screens/email_link_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/chess/presentation/screens/chess_lobby_screen.dart';
import '../../features/chess/presentation/screens/chess_match_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import 'go_router_refresh_stream.dart';

/// Router with auth-gated redirects. `redirect` re-runs whenever
/// [GoRouterRefreshStream] fires (every auth state change), so signing in,
/// signing out, or linking an email all move the user to the right screen
/// automatically instead of screens manually calling `context.go`.
final goRouterProvider = Provider<GoRouter>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: GoRouterRefreshStream(authRepository.onAuthStateChange),
    redirect: (context, state) =>
        _redirect(authRepository, state.matchedLocation),
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthChoiceScreen(),
      ),
      GoRoute(
        path: '/auth/link',
        builder: (context, state) => const EmailLinkScreen(),
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/chess',
        builder: (context, state) => const ChessLobbyScreen(),
      ),
      GoRoute(
        path: '/chess/:matchId',
        builder: (context, state) =>
            ChessMatchScreen(matchId: state.pathParameters['matchId']!),
      ),
    ],
  );
});

String? _redirect(AuthRepository authRepository, String location) {
  final hasSession = authRepository.currentSession != null;

  if (!hasSession) {
    // Signed-out users may only see the choice screen or the email-link
    // screen (used there for fresh sign-in/sign-up); everything else bounces
    // to the choice screen.
    return location.startsWith('/auth') ? null : '/auth';
  }

  // Signed in (including anonymous): splash and the choice screen have
  // nothing left to do, so send them to the lobby. `/auth/link` stays
  // reachable while signed in — that's the "save your account" upgrade path
  // for anonymous users, reached explicitly from the home screen banner.
  final isSplashOrChoice = location == '/splash' || location == '/auth';
  return isSplashOrChoice ? '/home' : null;
}

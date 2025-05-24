import 'package:edu_chat/pages/dialogue_quiz_page.dart';
import 'package:edu_chat/pages/home_page.dart';
import 'package:edu_chat/pages/learn_page.dart';
import 'package:edu_chat/pages/login_page.dart';
import 'package:edu_chat/pages/quiz_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart'; // Import ChangeNotifier

// Provider for the router
final routerProvider = Provider<GoRouter>((ref) {
  final authState = Supabase.instance.client.auth.onAuthStateChange;

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggingIn = state.matchedLocation == '/login';

      if (session == null) {
        return isLoggingIn ? null : '/login';
      }

      if (isLoggingIn) {
        return '/home';
      }

      return null;
    },
    refreshListenable: GoRouterRefreshStream(authState),
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/home', builder: (context, state) => const HomePage()),
      GoRoute(path: '/learn', builder: (context, state) => const LearnPage()),
      GoRoute(
        path: '/quiz',
        builder: (context, state) {
          final topicName = state.uri.queryParameters['topicName'];
          final subjectName = state.uri.queryParameters['subjectName'];
          // If we get a topicId directly, we can pass it too.
          // For now, QuizPage handles resolving/fetching topic details.
          return QuizPage(
            initialTopicName: topicName,
            initialSubjectName: subjectName,
          );
        },
      ),
      GoRoute(
        path: '/dialogue-quiz',
        builder: (context, state) {
          final topicId = state.uri.queryParameters['topicId'];
          final topicName = state.uri.queryParameters['topicName'];
          // quizSessionId will be managed by DialogueQuizPage or its providers for now.
          // It's important that DialogueQuizPage knows which topic the quiz is for.
          return DialogueQuizPage(topicId: topicId, topicName: topicName);
        },
      ),
    ],
  );
});

// Helper class to listen to auth changes for GoRouter
class GoRouterRefreshStream extends ChangeNotifier {
  // Extend ChangeNotifier
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    stream.asBroadcastStream().listen((_) => notifyListeners());
  }
}

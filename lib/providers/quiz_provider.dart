import 'package:edu_chat/services/llm_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Required for Supabase.instance.client
import 'package:edu_chat/services/supabase_service.dart'; // Required for SupabaseService

// You'll need to add `uuid: ^4.4.0` (or latest) to your pubspec.yaml
// and run `flutter pub get`

// Represents a single message in the chat dialogue (question or answer)
class ChatMessage {
  final String id;
  final String text;
  final bool isUserMessage;
  final DateTime timestamp;
  final Map<String, dynamic>?
  quizQuestionData; // Store original question data if it's a question
  final Map<String, dynamic>?
  quizEvaluationData; // Store evaluation if it's feedback

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUserMessage,
    required this.timestamp,
    this.quizQuestionData,
    this.quizEvaluationData,
  });
}

class QuizState {
  final String? topicId;
  final String? topicName;
  final String? quizSessionId; // <-- Add this
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;
  final int currentQuestionIndex;
  final int score;
  final bool quizCompleted;
  final Map<String, dynamic>? currentLlmQuestion;

  QuizState({
    this.topicId,
    this.topicName,
    this.quizSessionId, // <-- Add this
    this.messages = const [],
    this.isLoading = false,
    this.error,
    this.currentQuestionIndex = 0,
    this.score = 0,
    this.quizCompleted = false,
    this.currentLlmQuestion,
  });

  QuizState copyWith({
    String? topicId,
    String? topicName,
    String? quizSessionId, // <-- Add this
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
    int? currentQuestionIndex,
    int? score,
    bool? quizCompleted,
    Map<String, dynamic>? currentLlmQuestion,
    bool clearError = false,
  }) {
    return QuizState(
      topicId: topicId ?? this.topicId,
      topicName: topicName ?? this.topicName,
      quizSessionId: quizSessionId ?? this.quizSessionId, // <-- Add this
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      score: score ?? this.score,
      quizCompleted: quizCompleted ?? this.quizCompleted,
      currentLlmQuestion: currentLlmQuestion ?? this.currentLlmQuestion,
    );
  }
}

class QuizNotifier extends StateNotifier<QuizState> {
  final LLMService _llmService;
  final SupabaseService _supabaseService; // <-- Add SupabaseService
  final String? _initialTopicId;
  final String? _initialTopicName;
  final _uuid = const Uuid();
  final int _maxQuestionsPerQuiz = 3; // Define max questions

  QuizNotifier(
    this._llmService,
    this._supabaseService,
    this._initialTopicId,
    this._initialTopicName,
  ) // <-- Update constructor
  : super(QuizState(topicId: _initialTopicId, topicName: _initialTopicName)) {
    _startQuiz();
  }

  Future<void> _startQuiz() async {
    final currentUser = _supabaseClient.auth.currentUser;
    if (currentUser == null) {
      state = state.copyWith(
        error: "User not authenticated.",
        isLoading: false,
      );
      _addMessage(
        ChatMessage(
          id: _uuid.v4(),
          text: "Error: You must be logged in to start a quiz.",
          isUserMessage: false,
          timestamp: DateTime.now(),
        ),
      );
      return;
    }
    if (state.topicName == null) {
      state = state.copyWith(error: "Topic not specified.", isLoading: false);
      _addMessage(
        ChatMessage(
          id: _uuid.v4(),
          text: "Error: Topic not specified for the quiz.",
          isUserMessage: false,
          timestamp: DateTime.now(),
        ),
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      messages: [],
      currentQuestionIndex: 0,
      score: 0,
      quizCompleted: false,
      quizSessionId: null,
    );

    final sessionId = await _supabaseService.createQuizSession(
      userId: currentUser.id,
      topicId: state.topicId,
      topicName: state.topicName!,
      totalQuestions: _maxQuestionsPerQuiz, // Set total questions here
    );

    if (sessionId == null) {
      state = state.copyWith(
        error: "Failed to create quiz session.",
        isLoading: false,
      );
      _addMessage(
        ChatMessage(
          id: _uuid.v4(),
          text: "Error: Could not start the quiz session. Please try again.",
          isUserMessage: false,
          timestamp: DateTime.now(),
        ),
      );
      return;
    }

    state = state.copyWith(quizSessionId: sessionId);

    _addMessage(
      ChatMessage(
        id: _uuid.v4(),
        text: "Starting quiz for topic: ${state.topicName!}...",
        isUserMessage: false,
        timestamp: DateTime.now(),
      ),
    );
    await _fetchNextQuestion();
  }

  Future<void> _fetchNextQuestion() async {
    if (state.topicName == null || state.quizSessionId == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      if (state.currentQuestionIndex >= _maxQuestionsPerQuiz) {
        _endQuiz();
        return;
      }

      final questionData = await _llmService.generateQuizQuestion(
        state.topicName!,
      );
      state = state.copyWith(currentLlmQuestion: questionData);
      _addMessage(
        ChatMessage(
          id: _uuid.v4(),
          text: questionData['questionText'],
          isUserMessage: false,
          timestamp: DateTime.now(),
          quizQuestionData: questionData,
        ),
      );
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        error: "Failed to fetch question: $e",
        isLoading: false,
      );
      _addMessage(
        ChatMessage(
          id: _uuid.v4(),
          text: "Error: Could not load the next question.",
          isUserMessage: false,
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  Future<void> submitAnswer(String userAnswer) async {
    if (state.currentLlmQuestion == null ||
        state.isLoading ||
        state.quizSessionId == null) {
      return;
    }
    final currentUser = _supabaseClient.auth.currentUser;
    if (currentUser == null) {
      _addMessage(
        ChatMessage(
          id: _uuid.v4(),
          text: "Error: User session expired. Cannot save answer.",
          isUserMessage: false,
          timestamp: DateTime.now(),
        ),
      );
      state = state.copyWith(error: "User session expired.", isLoading: false);
      return;
    }

    state = state.copyWith(isLoading: true);
    _addMessage(
      ChatMessage(
        id: _uuid.v4(),
        text: userAnswer,
        isUserMessage: true,
        timestamp: DateTime.now(),
      ),
    );

    final currentQuestion = state.currentLlmQuestion!;
    final questionText = currentQuestion['questionText'] as String;
    final correctAnswer = currentQuestion['correctAnswer'] as String;

    try {
      final evaluation = await _llmService.evaluateAnswer(
        questionText,
        userAnswer,
        correctAnswer,
      );

      bool isCorrect = evaluation['isCorrect'] as bool;
      String feedback = evaluation['feedback'] as String;

      await _supabaseService.saveQuizAnswer(
        sessionId: state.quizSessionId!,
        userId: currentUser.id,
        questionText: questionText,
        userAnswer: userAnswer,
        correctAnswer: correctAnswer,
        isCorrect: isCorrect,
        llmFeedback: feedback,
      );

      _addMessage(
        ChatMessage(
          id: _uuid.v4(),
          text: feedback,
          isUserMessage: false,
          timestamp: DateTime.now(),
          quizEvaluationData: evaluation,
        ),
      );

      if (isCorrect) {
        state = state.copyWith(score: state.score + 1);
      }

      state = state.copyWith(
        currentQuestionIndex: state.currentQuestionIndex + 1,
        isLoading: false,
        currentLlmQuestion: null,
      );
      await _fetchNextQuestion();
    } catch (e) {
      state = state.copyWith(
        error: "Failed to evaluate or save answer: $e",
        isLoading: false,
      );
      _addMessage(
        ChatMessage(
          id: _uuid.v4(),
          text: "Error: Could not process your answer.",
          isUserMessage: false,
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  void _endQuiz() async {
    if (state.quizSessionId == null) {
      _addMessage(
        ChatMessage(
          id: _uuid.v4(),
          text: "Error: Quiz session ID missing. Cannot save final score.",
          isUserMessage: false,
          timestamp: DateTime.now(),
        ),
      );
      state = state.copyWith(
        quizCompleted: true,
        isLoading: false,
        currentLlmQuestion: null,
      );
      return;
    }

    await _supabaseService.updateQuizSession(
      sessionId: state.quizSessionId!,
      score: state.score,
      totalQuestions: _maxQuestionsPerQuiz, // Use the defined max questions
      completed: true,
    );

    final summaryMessage =
        "Quiz completed! Your score: ${state.score} out of $_maxQuestionsPerQuiz.";
    _addMessage(
      ChatMessage(
        id: _uuid.v4(),
        text: summaryMessage,
        isUserMessage: false,
        timestamp: DateTime.now(),
      ),
    );
    state = state.copyWith(
      quizCompleted: true,
      isLoading: false,
      currentLlmQuestion: null,
    );
  }

  void _addMessage(ChatMessage message) {
    state = state.copyWith(messages: [...state.messages, message]);
  }

  void resetQuiz() {
    // Re-initialize with the original topicId and topicName
    // The _startQuiz method will handle creating a new session.
    state = QuizState(topicId: _initialTopicId, topicName: _initialTopicName);
    _startQuiz();
  }

  // Helper to get Supabase client, rename to follow lowerCamelCase
  SupabaseClient get _supabaseClient => Supabase.instance.client;
}

final quizNotifierProvider = StateNotifierProvider.autoDispose
    .family<QuizNotifier, QuizState, ({String? topicId, String? topicName})>((
      ref,
      params,
    ) {
      final llmService = ref.watch(llmServiceProvider);
      final supabaseService = ref.watch(
        supabaseServiceProvider,
      ); // <-- Get SupabaseService from provider
      return QuizNotifier(
        llmService,
        supabaseService,
        params.topicId,
        params.topicName,
      ); // <-- Pass it to notifier
    });

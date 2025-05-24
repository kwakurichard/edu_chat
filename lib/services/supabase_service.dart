import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logging/logging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SupabaseService {
  final SupabaseClient _client;
  final _log = Logger('SupabaseService');

  SupabaseService(this._client);
  Future<List<Map<String, dynamic>>> getSubjects() async {
    try {
      _log.info('Fetching subjects from Supabase...');
      final response = await _client.from('subjects').select('*').order('name');
      _log.info('Received response: $response');
      return List<Map<String, dynamic>>.from(response);
    } catch (e, stack) {
      _log.severe('Error fetching subjects', e, stack);
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getRandomTopic(String subjectId) async {
    try {
      _log.info('Fetching random topic for subject: $subjectId');
      final response =
          await _client
              .from('topics')
              .select()
              .eq('subject_id', subjectId)
              .limit(1)
              .single();

      _log.info('Received topic: $response');
      return response;
    } catch (e, stack) {
      _log.severe('Error fetching random topic', e, stack);
      rethrow;
    }
  }

  Future<String?> createQuizSession({
    required String userId,
    String? topicId,
    required String topicName,
    int totalQuestions = 0,
  }) async {
    try {
      _log.info('Creating quiz session for user: $userId, topic: $topicName');
      final response = await _client
          .from('quiz_sessions')
          .insert({
            'user_id': userId,
            'topic_id': topicId,
            'topic_name': topicName,
            'total_questions': totalQuestions,
          })
          .select('id');

      if (response.isNotEmpty) {
        final sessionId = response[0]['id'] as String;
        _log.info('Created quiz session with ID: $sessionId');
        return sessionId;
      }
      _log.warning('Failed to create quiz session - no ID returned');
      return null;
    } catch (e, stack) {
      _log.severe('Error creating quiz session', e, stack);
      return null;
    }
  }

  Future<void> saveQuizAnswer({
    required String sessionId,
    required String userId,
    required String questionText,
    String? userAnswer,
    String? correctAnswer,
    required bool isCorrect,
    String? llmFeedback,
  }) async {
    try {
      _log.info('Saving quiz answer for session: $sessionId');
      await _client.from('quiz_answers').insert({
        'session_id': sessionId,
        'user_id': userId,
        'question_text': questionText,
        'user_answer': userAnswer,
        'correct_answer': correctAnswer,
        'is_correct': isCorrect,
        'llm_feedback': llmFeedback,
      });
      _log.info('Saved quiz answer successfully');
    } catch (e, stack) {
      _log.severe('Error saving quiz answer', e, stack);
      rethrow;
    }
  }

  Future<void> updateQuizSession({
    required String sessionId,
    required int score,
    required int totalQuestions,
    required bool completed,
  }) async {
    try {
      _log.info('Updating quiz session: $sessionId');
      await _client
          .from('quiz_sessions')
          .update({
            'score': score,
            'total_questions': totalQuestions,
            'completed_at': completed ? DateTime.now().toIso8601String() : null,
          })
          .eq('id', sessionId);
      _log.info('Updated quiz session successfully');
    } catch (e, stack) {
      _log.severe('Error updating quiz session', e, stack);
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> findTopicByName(
    String topicName,
    String subjectName,
  ) async {
    try {
      _log.info('Finding topic: $topicName in subject: $subjectName');
      final topics =
          await _client
              .from('topics')
              .select('*, subjects!inner(*)')
              .eq('subjects.name', subjectName)
              .eq('name', topicName)
              .limit(1)
              .single();

      _log.info('Found topic: $topics');
      return topics;
    } catch (e, stack) {
      _log.warning('Topic not found or error occurred', e, stack);
      // Create a temporary topic since this is just a mock
      return {
        'id': 'temp-${topicName.replaceAll(' ', '-').toLowerCase()}',
        'name': topicName,
        'subject_id': 'temp-subject',
        'created_at': DateTime.now().toIso8601String(),
      };
    }
  }
}

// Provider for SupabaseService
final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService(Supabase.instance.client);
});

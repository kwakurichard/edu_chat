import 'package:edu_chat/models/topic.dart';
import 'package:edu_chat/services/supabase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Provider for the current topic on the QuizPage
// This could be expanded if more complex logic is needed around the topic
final quizPageTopicProvider = StateProvider<Topic?>((ref) => null);

class QuizPage extends ConsumerWidget {
  final String? initialTopicName;
  final String? initialSubjectName;

  const QuizPage({super.key, this.initialTopicName, this.initialSubjectName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supabaseService = ref.watch(supabaseServiceProvider);

    return FutureBuilder<Map<String, dynamic>?>(
      // Get subject ID from initialSubjectName
      future: supabaseService.findTopicByName(
        initialTopicName ?? '',
        initialSubjectName ?? '',
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error loading topic: ${snapshot.error}'));
        }

        final topic = snapshot.data;
        if (topic == null) {
          return const Center(child: Text('No topics found for this subject'));
        }

        // Use the topic data
        return QuizView(topic: topic);
      },
    );
  }
}

class QuizView extends ConsumerStatefulWidget {
  final Map<String, dynamic> topic;

  const QuizView({super.key, required this.topic});

  @override
  ConsumerState<QuizView> createState() => _QuizViewState();
}

class _QuizViewState extends ConsumerState<QuizView> {
  bool _isLoading = false;
  String? _error;
  Topic? _currentTopic;

  @override
  void initState() {
    super.initState();
    _initializeTopic();
  }

  Future<void> _initializeTopic() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _currentTopic = null; // Reset current topic
    });

    try {
      // If a topic name is provided, we assume it's valid for now.
      // In a real app, you might want to fetch the full Topic object from Supabase
      // using initialTopicName and initialSubjectName to get its ID and other details.
      // For this mock, we'll create a temporary Topic object.
      // A more robust solution would be to ensure LearnPage passes a Topic object or ID.
      setState(() {
        _currentTopic = Topic(
          id: 'temp-${widget.topic['name'].replaceAll(' ', '-').toLowerCase()}', // Temporary ID
          name: widget.topic['name'],
          subjectId: 'temp-subject', // Temporary subject ID
          createdAt: DateTime.now(),
        );
      });
      ref.read(quizPageTopicProvider.notifier).state = _currentTopic;
    } catch (e) {
      setState(() {
        _error = 'An error occurred: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _startDialogueQuiz() {
    if (_currentTopic != null) {
      // Navigate to DialogueQuizPage, passing topicId if available, or topicName.
      // The DialogueQuizPage will then handle fetching questions for this topic.
      context.go(
        '/dialogue-quiz?topicId=${_currentTopic!.id}&topicName=${Uri.encodeComponent(_currentTopic!.name)}',
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No topic selected or fetched.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final topicToDisplay = ref.watch(quizPageTopicProvider) ?? _currentTopic;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.topic['name'] == null
              ? 'Surprise Quiz'
              : 'Quiz for ${widget.topic['name']}',
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child:
              _isLoading
                  ? const CircularProgressIndicator()
                  : _error != null
                  ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Error: $_error',
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _initializeTopic,
                        child: const Text('Try Again'),
                      ),
                    ],
                  )
                  : topicToDisplay != null
                  ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        'Topic:',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        topicToDisplay.name,
                        style: Theme.of(context).textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      if (widget.topic['subjectName'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            '(Subject: ${widget.topic['subjectName']})',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                      const SizedBox(height: 40),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('Start Dialogue Quiz'),
                        onPressed: _startDialogueQuiz,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 30,
                            vertical: 15,
                          ),
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ],
                  )
                  : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('No topic loaded.'),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _initializeTopic,
                        child: const Text('Load Topic'),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }
}

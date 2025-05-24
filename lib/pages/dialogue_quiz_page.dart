import 'package:edu_chat/providers/quiz_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DialogueQuizPage extends ConsumerStatefulWidget {
  final String? topicId;
  final String? topicName;

  const DialogueQuizPage({super.key, this.topicId, this.topicName});

  @override
  ConsumerState<DialogueQuizPage> createState() => _DialogueQuizPageState();
}

class _DialogueQuizPageState extends ConsumerState<DialogueQuizPage> {
  final _answerController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _answerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use the family provider, passing the topicId and topicName
    final quizState = ref.watch(
      quizNotifierProvider((
        topicId: widget.topicId,
        topicName: widget.topicName,
      )),
    );
    final quizNotifier = ref.read(
      quizNotifierProvider((
        topicId: widget.topicId,
        topicName: widget.topicName,
      )).notifier,
    );

    // Scroll to bottom when messages change
    ref.listen(
      quizNotifierProvider((
        topicId: widget.topicId,
        topicName: widget.topicName,
      )).select((state) => state.messages),
      (_, __) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Quiz: ${widget.topicName ?? "Loading..."}'),
        actions: [
          if (quizState.quizCompleted)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => quizNotifier.resetQuiz(),
              tooltip: 'Restart Quiz',
            ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8.0),
              itemCount: quizState.messages.length,
              itemBuilder: (context, index) {
                final message = quizState.messages[index];
                return _buildMessageBubble(message, context);
              },
            ),
          ),
          if (quizState.isLoading &&
              quizState.messages.isNotEmpty &&
              !quizState.quizCompleted)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  SizedBox(width: 10),
                  CircularProgressIndicator(strokeWidth: 2),
                  SizedBox(width: 10),
                  Text("EduChat is thinking..."),
                ],
              ),
            ),
          if (quizState.error != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Error: ${quizState.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          if (!quizState.quizCompleted &&
              !quizState.isLoading &&
              quizState.currentLlmQuestion != null)
            _buildAnswerInputArea(quizNotifier, quizState)
          else if (quizState.quizCompleted)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    "Quiz Finished! Score: ${quizState.score}",
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => context.go('/home'),
                    child: const Text('Back to Home'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, BuildContext context) {
    final bool isUser = message.isUserMessage;
    final alignment =
        isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final color =
        isUser
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.secondary;
    final textColor =
        isUser
            ? Theme.of(context).colorScheme.onPrimary
            : Theme.of(context).colorScheme.onSecondary;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: alignment,
        children: <Widget>[
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 14.0,
              vertical: 10.0,
            ),
            decoration: BoxDecoration(
              color: color.withValues(
                alpha: color.a * 0.8,
                red: color.r.toDouble(),
                green: color.g.toDouble(),
                blue: color.b.toDouble(),
              ),
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Text(message.text, style: TextStyle(color: textColor)),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2.0, left: 8.0, right: 8.0),
            child: Text(
              "${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}",
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerInputArea(QuizNotifier quizNotifier, QuizState quizState) {
    final currentQuestionData = quizState.currentLlmQuestion;
    final options =
        currentQuestionData?['options']
            as List<dynamic>?; // e.g. ['Opt A', 'Opt B']

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          if (options != null && options.isNotEmpty)
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              alignment: WrapAlignment.center,
              children:
                  options.map((option) {
                    return ElevatedButton(
                      onPressed: () {
                        quizNotifier.submitAnswer(option.toString());
                      },
                      child: Text(option.toString()),
                    );
                  }).toList(),
            )
          else // Fallback to text input if no options
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _answerController,
                    decoration: const InputDecoration(
                      hintText: 'Type your answer...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        quizNotifier.submitAnswer(value);
                        _answerController.clear();
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    if (_answerController.text.isNotEmpty) {
                      quizNotifier.submitAnswer(_answerController.text);
                      _answerController.clear();
                    }
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'package:edu_chat/models/subject.dart';
import 'package:edu_chat/services/llm_service.dart';
import 'package:edu_chat/services/supabase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';

final _log = Logger('LearnPage');

// Provider to fetch subjects from Supabase
final subjectsProvider = FutureProvider<List<Subject>>((ref) async {
  try {
    final supabaseService = ref.watch(supabaseServiceProvider);
    _log.info('Fetching subjects from Supabase...');
    final subjects = await supabaseService.getSubjects();
    _log.info('Received subjects: $subjects');
    return subjects.map((json) => Subject.fromJson(json)).toList();
  } catch (e, stack) {
    _log.severe('Error fetching subjects', e, stack);
    rethrow;
  }
});

// Provider to manage the generated notes state
final generatedNotesProvider = StateProvider<String?>((ref) => null);

// Provider for the currently selected subject
final selectedSubjectProvider = StateProvider<Subject?>((ref) => null);

class LearnPage extends ConsumerStatefulWidget {
  const LearnPage({super.key});

  @override
  ConsumerState<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends ConsumerState<LearnPage> {
  final _topicController = TextEditingController();
  bool _isGeneratingNotes = false;

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _generateNotes() async {
    if (!mounted) return; // Add this check

    final subject = ref.read(selectedSubjectProvider);
    final topic = _topicController.text.trim();

    if (subject == null || topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a subject and enter a topic'),
        ),
      );
      return;
    }

    setState(() => _isGeneratingNotes = true);
    ref.read(generatedNotesProvider.notifier).state = null;

    try {
      final llmService = ref.read(llmServiceProvider);
      final notes = await llmService.generateTopicSummary(subject.name, topic);
      if (!mounted) return;
      ref.read(generatedNotesProvider.notifier).state = notes;
    } catch (e, stack) {
      _log.severe('Failed to generate notes', e, stack);
      if (!mounted) return;

      final message =
          e is TimeoutException
              ? 'Request timed out. Please try again.'
              : 'Failed to generate notes: ${e.toString()}';

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _isGeneratingNotes = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _log.info('Building LearnPage');
    final subjects = ref.watch(subjectsProvider);
    final selectedSubject = ref.watch(selectedSubjectProvider);
    final generatedNotes = ref.watch(generatedNotesProvider);

    _log.info('''
    Build state:
    - Subjects count: ${subjects.value?.length ?? 'loading'}
    - Selected subject: ${selectedSubject?.name ?? 'none'}
    - Has generated notes: ${generatedNotes != null}
  ''');

    _log.info('Subjects provider state: ${subjects.toString()}');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Learn a Topic'),
        backgroundColor:
            Theme.of(
              context,
            ).colorScheme.primaryContainer, // Make AppBar visible
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/home'),
          ),
        ],
      ),
      body: Container(
        // Add container with color to check if body is rendering
        color: Theme.of(context).scaffoldBackgroundColor,
        child: subjects.when(
          data: (subjectsList) {
            _log.info('Subjects loaded: ${subjectsList.length} items');
            if (subjectsList.isEmpty) {
              return const Center(
                child: Text('No subjects found. Please check your database.'),
              );
            }
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<Subject>(
                    decoration: const InputDecoration(
                      labelText: 'Select Subject',
                      border: OutlineInputBorder(),
                    ),
                    value: selectedSubject,
                    items:
                        subjectsList.map((subject) {
                          return DropdownMenuItem(
                            value: subject,
                            child: Text(subject.name),
                          );
                        }).toList(),
                    onChanged: (Subject? value) {
                      ref.read(selectedSubjectProvider.notifier).state = value;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _topicController,
                    decoration: const InputDecoration(
                      labelText: 'Enter Topic',
                      border: OutlineInputBorder(),
                      hintText: 'e.g., Photosynthesis, World War II, etc.',
                    ),
                    onChanged: (value) {
                      // Remove leading/trailing whitespace and multiple spaces
                      final sanitized = value.trim().replaceAll(
                        RegExp(r'\s+'),
                        ' ',
                      );
                      if (sanitized != value) {
                        _topicController.text = sanitized;
                        _topicController.selection = TextSelection.fromPosition(
                          TextPosition(offset: sanitized.length),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isGeneratingNotes ? null : _generateNotes,
                    icon:
                        _isGeneratingNotes
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.auto_stories),
                    label: Text(
                      _isGeneratingNotes ? 'Generating...' : 'Generate Notes',
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (generatedNotes != null) ...[
                    Expanded(
                      child: Card(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Generated Notes',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(generatedNotes),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.quiz),
                                label: const Text('Start Quiz'),
                                onPressed:
                                    (selectedSubject != null &&
                                            _topicController.text
                                                .trim()
                                                .isNotEmpty)
                                        ? () {
                                          final topicName =
                                              _topicController.text.trim();
                                          context.go(
                                            '/quiz?topicName=${Uri.encodeComponent(topicName)}&subjectName=${Uri.encodeComponent(selectedSubject.name)}',
                                          );
                                        }
                                        : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
          loading: () {
            _log.info('Subjects loading...');
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading subjects...'),
                ],
              ),
            );
          },
          error: (error, stack) {
            _log.severe('Error loading subjects', error, stack);
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: $error'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => ref.refresh(subjectsProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

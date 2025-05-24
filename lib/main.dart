import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logging/logging.dart';
import 'package:edu_chat/routes/app_router.dart'; // Add this import

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Setup logging
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
  });

  final log = Logger('main');

  try {
    // Load environment variables
    await dotenv.load();
    log.info('Environment variables loaded');
    log.info('SUPABASE_URL exists: ${dotenv.env['SUPABASE_URL'] != null}');
    log.info(
      'SUPABASE_ANON_KEY exists: ${dotenv.env['SUPABASE_ANON_KEY'] != null}',
    );

    // Initialize Supabase
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );

    // Test connection
    try {
      final response = await Supabase.instance.client
          .from('subjects')
          .select('*')
          .limit(1);
      log.info('Test query successful: $response');
    } catch (e) {
      log.warning('Test query failed: $e');
    }

    log.info('***** Supabase init completed *****');
  } catch (e, stack) {
    log.severe('Error during initialization', e, stack);
    rethrow;
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'EduChat',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}

final supabase = Supabase.instance.client;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Providers
import 'providers/auth_provider.dart';
import 'providers/vocabulary_provider.dart';
import 'providers/learning_provider.dart';
import 'providers/review_provider.dart';
import 'providers/statistics_provider.dart';

// Pages
import 'ui/pages/main_page.dart';

// Database
import 'database/local_database.dart';

// Services
import 'services/api_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final database = LocalDatabase();
  await database.initialize();
  
  final apiClient = ApiClient();
  
  runApp(MyApp(database: database, apiClient: apiClient));
}

class MyApp extends StatelessWidget {
  final LocalDatabase database;
  final ApiClient apiClient;
  
  const MyApp({super.key, required this.database, required this.apiClient});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<LocalDatabase>.value(value: database),
        ChangeNotifierProvider(create: (_) => AuthProvider(apiClient)),
        ChangeNotifierProvider(create: (_) => VocabularyProvider(apiClient, database)),
        ChangeNotifierProvider(create: (_) => LearningProvider(database)),
        ChangeNotifierProvider(create: (_) => ReviewProvider(database)),
        ChangeNotifierProvider(create: (_) => StatisticsProvider(database)),
      ],
      child: MaterialApp(
        title: 'AI背单词',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const MainPage(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

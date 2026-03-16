import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'api_service.dart';
import 'screens/upload_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>(create: (_) => ApiService()),
      ],
      child: const RicorsoFacileApp(),
    ),
  );
}

class RicorsoFacileApp extends StatelessWidget {
  const RicorsoFacileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RicorsoFacile POC',
      theme: AppTheme.lightTheme,
      home: const UploadScreen(),
    );
  }
}

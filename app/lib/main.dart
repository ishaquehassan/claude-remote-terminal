import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/terminal_service.dart';
import 'services/language_service.dart';
import 'screens/connect_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TerminalService()),
        ChangeNotifierProvider(create: (_) => LanguageService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Claude Remote',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D0B09),
        colorScheme: const ColorScheme.dark(primary: Color(0xFFE07845)),
      ),
      home: const ConnectScreen(),
    );
  }
}

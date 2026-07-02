import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'login_page.dart';
import 'owner_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isLoggedIn = false; // Only owner can login now

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Technician Tracker - Owner Dashboard',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF005A9C)),
        primaryColor: const Color(0xFF005A9C),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF005A9C),
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF005A9C),
            foregroundColor: Colors.white,
          ),
        ),
      ),
      home: _isLoggedIn
          ? const OwnerDashboard()
          : LoginPage(
              onLoginSuccess: () {
                setState(() => _isLoggedIn = true);
              },
            ),
      debugShowCheckedModeBanner: false,
    );
  }
}

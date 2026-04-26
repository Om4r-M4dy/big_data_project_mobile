import 'package:flutter/material.dart';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'features/splash/presentation/pages/splash_page.dart';

void main() {
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const SearchApp());
}

class SearchApp extends StatelessWidget {
  const SearchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Books Search Engine',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF10B981),
          brightness: Brightness.light,
          surface: Colors.white,
          surfaceContainerHighest: const Color(0xFFF1F5F9),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
          ),
          prefixIconColor: const Color(0xFF94A3B8),
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(
            fontFamily: 'Inter',
            color: Color(0xFF1E293B),
          ),
        ),
      ),
      home: const SplashPage(),
    );
  }
}
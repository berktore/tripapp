import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TripApp());
}

class TripApp extends StatelessWidget {
  const TripApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TripApp',
      debugShowCheckedModeBanner: false,

      // Türkçe dil desteği
      locale: const Locale('tr', 'TR'),

      supportedLocales: const [Locale('tr', 'TR'), Locale('en', 'US')],

      // Tarih seçici ve Material bileşenleri için yerelleştirme
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // Uygulama teması
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppTheme.navy,
          primary: AppTheme.navy,
          secondary: AppTheme.teal,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: AppTheme.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppTheme.background,
          foregroundColor: AppTheme.navy,
          elevation: 0,
          centerTitle: false,
        ),
        fontFamily: 'Inter',
      ),

      // Açılış ekranı
      home: const HomeScreen(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const navy = Color(0xFF123B50);
  static const deepNavy = Color(0xFF082D3D);
  static const teal = Color(0xFF13B8B0);
  static const background = Color(0xFFF5F8F8);
  static const muted = Color(0xFF71838C);

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.fromSeed(seedColor: teal),
    textTheme: GoogleFonts.interTextTheme(),
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      foregroundColor: navy,
      elevation: 0,
    ),
  );
}

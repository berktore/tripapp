import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const navy = Color(0xFF123B50);
  static const deepNavy = Color(0xFF082D3D);
  static const teal = Color(0xFF13B8B0);
  static const background = Color(0xFFF5F8F8);
  static const muted = Color(0xFF71838C);
  static const border = Color(0xFFEAF0EF);
  static const surface = Colors.white;
  static const softTeal = Color(0xFFE1F3F0);
  static const navBackground = Color(0xFFEAF0EF);

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: navy,
      primary: navy,
      secondary: teal,
      surface: surface,
      brightness: Brightness.light,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
    );

    final bodyText = GoogleFonts.interTextTheme(base.textTheme);
    final headingText = GoogleFonts.plusJakartaSansTextTheme(base.textTheme);

    final textTheme = bodyText.copyWith(
      displayLarge: headingText.displayLarge?.copyWith(
        fontWeight: FontWeight.w800,
        color: navy,
      ),
      displayMedium: headingText.displayMedium?.copyWith(
        fontWeight: FontWeight.w800,
        color: navy,
      ),
      displaySmall: headingText.displaySmall?.copyWith(
        fontWeight: FontWeight.w800,
        color: navy,
      ),
      headlineLarge: headingText.headlineLarge?.copyWith(
        fontWeight: FontWeight.w800,
        color: navy,
      ),
      headlineMedium: headingText.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        color: navy,
      ),
      headlineSmall: headingText.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: navy,
      ),
      titleLarge: headingText.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: navy,
      ),
      titleMedium: headingText.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: navy,
      ),
      bodyLarge: bodyText.bodyLarge?.copyWith(color: navy),
      bodyMedium: bodyText.bodyMedium?.copyWith(color: navy),
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: navy,
        elevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: navBackground,
        indicatorColor: softTeal,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? navy : muted,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: teal, width: 1.4),
        ),
      ),
    );
  }
}

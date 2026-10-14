import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Iconic Black & Pink Luxury Palette
  static const Color storyTvPink =
      Color(0xFFE90064); // Exact StoryUp Vibrant Magenta Pink
  static const Color storyTvPinkDark =
      Color(0xFFB8004F); // Darker StoryUp Magenta
  static const Color storyTvCard = Color(0xFF141416); // StoryUp Card Background
  static const Color pinkPrimary = storyTvPink; // Vibrant Electric Hot Pink
  static const Color pinkBright = Color(0xFFFF5EA8); // Bright Neon Pink
  static const Color pinkDeep = storyTvPinkDark; // Deep Rose Ruby / Magenta
  static const Color pinkDark = Color(0xFF880E4F); // Dark Burgundy Pink Accent
  static const Color pinkGlow = Color(0xFFFF85C2); // Soft Pink Glow Accent
  static const Color pinkBorder = Color(0xFF3D182E); // Subtle Pink-Black Border

  // Deep Obsidian Black Surfaces
  static const Color dramaBlack = Color(0xFF000000); // Pure Pitch Black
  static const Color dramaDarkSurface =
      Color(0xFF0D0D12); // Midnight Black Surface
  static const Color dramaCard =
      Color(0xFF16161D); // Elevated Card with subtle dark tone
  static const Color dramaElevated = Color(0xFF1F1F28); // Floating Card Surface
  static const Color dramaBorder =
      Color(0xFF2E1727); // Clean Pink-Black Tone Border

  // Secondary Accents
  static const Color dramaGold = Color(0xFFFFD166);
  static const Color dramaGoldLight = Color(0xFFFFE599);
  static const Color dramaCyan = Color(0xFF38BDF8);
  static const Color phonePeViolet = Color(0xFF5F259F); // PhonePe UPI Violet

  // Text Colors
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textMuted =
      Color(0xFFD3C5D0); // Crisp Light Grayish-Pink for optimal readability
  static const Color textDark = Color(0xFF807180);

  // Status Colors
  static const Color successGreen = Color(0xFF10B981);
  static const Color warningOrange = Color(0xFFF59E0B);
  static const Color errorRed = Color(0xFFEF4444);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: dramaBlack,
      primaryColor: storyTvPink,
      cardColor: dramaCard,
      colorScheme: const ColorScheme.dark(
        primary: storyTvPink,
        secondary: pinkBright,
        surface: dramaDarkSurface,
        error: errorRed,
      ),
      textTheme:
          GoogleFonts.montserratTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.bebasNeue(
            color: textWhite, fontSize: 32, letterSpacing: 1.2),
        displayMedium: GoogleFonts.bebasNeue(
            color: textWhite, fontSize: 24, letterSpacing: 1.0),
        titleLarge: GoogleFonts.montserrat(
            color: textWhite, fontSize: 18, fontWeight: FontWeight.bold),
        titleMedium: GoogleFonts.montserrat(
            color: textWhite, fontSize: 15, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.montserrat(color: textWhite, fontSize: 14),
        bodyMedium: GoogleFonts.montserrat(color: textMuted, fontSize: 12),
        bodySmall: GoogleFonts.montserrat(color: textDark, fontSize: 10),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: dramaBlack,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textWhite),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: dramaBlack,
        selectedItemColor: storyTvPink,
        unselectedItemColor: Color(0xFF888888),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dramaDarkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

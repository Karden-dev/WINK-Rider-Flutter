// lib/utils/app_theme.dart

import 'package:flutter/material.dart';

class AppTheme {
  // Couleurs principales basées sur le CSS fourni
  static const Color primaryColor = Color(0xFFFF7F50); // --clr-primary: Corail
  static const Color primaryLight = Color(0xFFFFD8C7); // Corail clair pour les fonds de cartes
  static const Color secondaryColor = Color(0xFF2C3E50); // --clr-secondary: Bleu Profond
  static const Color accentColor = Color(0xFF4A6491); // --clr-accent: Bleu Céleste
  static const Color background = Color(0xFFF8F9FA); // --clr-background: Blanc Crème
  static const Color text = Color(0xFF34495E); // --clr-text: Gris Anthracite
  static const Color danger = Color(0xFFdc3545); // Pour les statuts annulés/ratés
  static const Color success = Color(0xFF28a745); // Pour les statuts livrés
  static const Color info = Color(0xFF0dcaf0); // Pour les statuts "Prêt" ou Infos

  static final ThemeData lightTheme = ThemeData(
    primaryColor: primaryColor,
    // Utiliser le scheme de couleur basé sur le corail
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      primary: primaryColor,
      secondary: secondaryColor,
      surface: background,
      error: danger,
      background: background,
    ),
    scaffoldBackgroundColor: background,
    
    // Thème de l'AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: secondaryColor, // Utiliser le bleu profond pour la barre supérieure (comme la sidebar de l'admin)
      foregroundColor: Colors.white,
      elevation: 4, // Légère élévation
      centerTitle: true,
    ),
    
    // Thème des boutons principaux (ElevatedButton)
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
        elevation: 3,
      ),
    ),

    // Thème des Floating Action Buttons
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
    ),
    
    // Thème des champs de saisie (Inputs)
    inputDecorationTheme: InputDecorationTheme(
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: primaryColor, width: 2.0),
        borderRadius: BorderRadius.circular(10.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10.0),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: danger),
        borderRadius: BorderRadius.circular(10.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: danger, width: 2.0),
        borderRadius: BorderRadius.circular(10.0),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
    ),
    
    // Thème des cartes pour la cohérence
    cardTheme: CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
    ),
    
    // Thème des textes
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontWeight: FontWeight.bold, color: secondaryColor),
      headlineSmall: TextStyle(fontWeight: FontWeight.w600, color: text),
    ),
  );
}
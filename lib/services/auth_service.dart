// lib/services/auth_service.dart

import 'dart:convert';
import 'package:dio/dio.dart'; // Import nécessaire pour Dio
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart'; // Import nécessaire pour ChangeNotifier
import '../models/user.dart';

class AuthService extends ChangeNotifier {
  // CORRECTION: Utilisation de l'IP spéciale pour l'émulateur Android
  static const String _apiBaseUrl = "http://10.0.2.2:3000/api"; // Adaptez si nécessaire
  static const String _userKey = "currentUser";

  final Dio _dio = Dio();

  // CORRECTION : Getter public pour l'instance Dio partagée
  Dio get dio => _dio;

  User? _currentUser;
  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  // Initialisation : Tente de charger l'utilisateur depuis le stockage local
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);

    if (userJson != null) {
      _currentUser = User.fromJson(jsonDecode(userJson));
      _dio.options.headers["Authorization"] = "Bearer ${_currentUser!.token}";
      // Sécurité : S'assurer que seul un Livreur est conservé en session
      if (_currentUser!.role != 'livreur') {
        logout();
      }
    }
  }

  // Appel à l'API de connexion
  Future<void> login(String phoneNumber, String pin, {required bool rememberMe}) async {
    try {
      final response = await _dio.post(
        '$_apiBaseUrl/login',
        data: { 'phoneNumber': phoneNumber, 'pin': pin },
      );

      final userData = response.data['user'];
      final user = User.fromJson(userData);

      if (user.role != 'livreur') {
        throw Exception("Accès refusé : Seuls les livreurs sont autorisés.");
      }

      _currentUser = user;

      // Logique "Se souvenir de moi" : sauvegarde seulement si `rememberMe` est vrai.
      if (rememberMe) { 
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_userKey, jsonEncode(user.toJson()));
      }

      _dio.options.headers["Authorization"] = "Bearer ${user.token}";

      notifyListeners(); // Déclenche le rechargement de l'UI (dans main.dart)

    } on DioException catch (e) {
      String message = e.response?.data['message'] ?? 'Erreur de connexion inconnue.';
      throw Exception(message);
    }
  }

  // Déconnexion
  Future<void> logout() async {
    _currentUser = null;
    _dio.options.headers.remove("Authorization");
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);

    notifyListeners(); // Déclenche le rechargement de l'UI
  }
}
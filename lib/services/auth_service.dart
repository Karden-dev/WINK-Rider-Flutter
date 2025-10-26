// lib/services/auth_service.dart

import 'dart:convert';
import 'package:dio/dio.dart'; // Import nécessaire pour Dio
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart'; // Import nécessaire pour ChangeNotifier
import '../models/user.dart';

class AuthService extends ChangeNotifier {
  // Gardez l'URL locale pour le développement pour l'instant
  // Utilisez 10.0.2.2 pour l'émulateur Android standard
  // Utilisez l'IP locale de votre machine (ex: http://192.168.1.10:3000/api) pour un appareil physique sur le même réseau Wifi
  static const String _apiBaseUrl = "http://10.0.2.2:3000/api";
  
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
      try { // Ajouter un try-catch pour le parsing
        _currentUser = User.fromJson(jsonDecode(userJson));
        _dio.options.headers["Authorization"] = "Bearer ${_currentUser!.token}";
        // Sécurité : S'assurer que seul un Livreur est conservé en session
        if (_currentUser!.role != 'livreur') {
          await logout(); // Utiliser await pour s'assurer que la déconnexion est complète
        }
      } catch (e) {
         debugPrint("Erreur parsing User JSON depuis SharedPreferences: $e");
         await logout(); // Déconnecter si les données sont corrompues
      }
    }
  }

  // Appel à l'API de connexion
  Future<void> login(String phoneNumber, String pin) async {
    try {
      final response = await _dio.post(
        '$_apiBaseUrl/login',
        data: { 'phoneNumber': phoneNumber, 'pin': pin },
      );

      // Vérifier si la réponse contient bien les données attendues
      if (response.data == null || response.data['user'] == null) {
        throw Exception("Réponse invalide du serveur lors de la connexion.");
      }

      final userData = response.data['user'];
      final user = User.fromJson(userData);

      if (user.role != 'livreur') {
        throw Exception("Accès refusé : Seuls les livreurs sont autorisés.");
      }

      _currentUser = user;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(user.toJson()));

      _dio.options.headers["Authorization"] = "Bearer ${user.token}";

      notifyListeners(); // Déclenche le rechargement de l'UI (dans main.dart)

    } on DioException catch (e) {
      String message = e.response?.data?['message'] ?? e.message ?? 'Erreur de connexion inconnue.';
      // Améliorer le message d'erreur pour les problèmes réseau
      if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.sendTimeout || e.type == DioExceptionType.receiveTimeout) {
        message = "Impossible de joindre le serveur. Vérifiez votre connexion et l'adresse IP ($_apiBaseUrl).";
      } else if (e.response?.statusCode == 401) {
          message = e.response?.data?['message'] ?? "Identifiants incorrects."; // Message plus spécifique pour 401
      }
      debugPrint("DioException lors du login: ${e.message} - Response: ${e.response?.data}");
      throw Exception(message);
    } catch (e) { // Capturer d'autres erreurs potentielles (ex: parsing JSON)
        debugPrint("Erreur inattendue lors du login: $e");
        throw Exception("Une erreur inattendue est survenue lors de la connexion.");
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
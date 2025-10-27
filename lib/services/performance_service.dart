// lib/services/performance_service.dart

import 'package:dio/dio.dart';
import 'package:flutter/material.dart'; // Pour debugPrint
// import 'package:intl/intl.dart';      // Suppression: L'importation n'est plus utilisée

import '../models/performance_data.dart';
// import '../models/user.dart'; // Suppression: Plus besoin d'importer User

class PerformanceService {
  final Dio _dio;
  // final User _currentUser; // Suppression: Le champ n'est pas utilisé, l'ID est déduit par le token.
  static const String _apiBaseUrl = "http://10.0.2.2:3000/api/performance"; // Base API Performance

  PerformanceService(this._dio); // Constructeur simplifié

  /// Récupère les données de performance pour une période donnée.
  /// Appelle GET /api/performance
  Future<PerformanceData> fetchPerformanceData(String periodCode) async {
    try {
      final response = await _dio.get(
        _apiBaseUrl, // L'endpoint GET '/'
        queryParameters: {
          'period': periodCode,
          // L'API déduit l'ID du livreur via le token
        },
      );

      // Le backend renvoie directement l'objet PerformanceData
      return PerformanceData.fromJson(response.data);

    } on DioException catch (e) {
      String message = e.response?.data['message'] ?? 'Échec de la récupération des performances.';
      debugPrint("DioException fetchPerformanceData: ${e.message} - Response: ${e.response?.data}");
      throw Exception(message);
    } catch (e) {
      debugPrint("Erreur inattendue fetchPerformanceData: $e");
      throw Exception("Une erreur inattendue est survenue.");
    }
  }

   /// Met à jour les objectifs personnels du livreur.
   /// Appelle PUT /api/performance/personal-goals
  Future<void> updatePersonalGoals(PersonalGoals goals) async {
    try {
      await _dio.put(
        '$_apiBaseUrl/personal-goals',
         data: goals.toJson(), // Envoie les données JSON
         // L'API déduit l'ID du livreur via le token
      );
    } on DioException catch (e) {
      String message = e.response?.data['message'] ?? 'Échec de la mise à jour des objectifs.';
       debugPrint("DioException updatePersonalGoals: ${e.message} - Response: ${e.response?.data}");
      throw Exception(message);
    } catch (e) {
      debugPrint("Erreur inattendue updatePersonalGoals: $e");
      throw Exception("Une erreur inattendue est survenue.");
    }
  }

}
// lib/services/order_service.dart

import 'dart:convert'; // <-- AJOUTÉ POUR jsonEncode
import 'package:dio/dio.dart';
import 'package:intl/intl.dart'; 
import 'package:connectivity_plus/connectivity_plus.dart'; // <-- AJOUTÉ
import '../models/order.dart';
import '../models/user.dart'; 
import '../models/rider_cash_details.dart'; 
import '../models/sync_request.dart'; // <-- AJOUTÉ (Assurez-vous que ce modèle existe)
import 'sync_service.dart'; // <-- AJOUTÉ

class OrderService {
  final Dio _dio;
  final User _currentUser;
  final SyncService _syncService; // <-- AJOUTÉ
  
  static const String _apiBaseUrl = "http://10.0.2.2:3000/api/rider"; 

  OrderService(this._dio, this._currentUser, this._syncService); // <-- CONSTRUCTEUR MIS À JOUR

  // Mappers de traduction (basé sur public/js/rider-common.js)
  final statusTranslations = {
    'pending': 'En attente',
    'in_progress': 'Assignée',
    'ready_for_pickup': 'Prête à prendre',
    'en_route': 'En route',
    'delivered': 'Livrée',
    'cancelled': 'Annulée',
    'failed_delivery': 'Livraison ratée',
    'reported': 'À relancer',
    'return_declared': 'Retour déclaré',
    'returned': 'Retournée'
  };

  /// Récupère les commandes pour un statut donné (ex: 'today', 'relaunch', 'myrides').
  Future<List<Order>> fetchRiderOrders({
    required List<String> statuses, 
    String? startDate, 
    String? endDate,
    String? search,
  }) async {
    try {
      final String statusQuery = statuses.join(','); 

      final response = await _dio.get(
        '$_apiBaseUrl/orders',
        queryParameters: {
          'status': statusQuery,
          'startDate': startDate,
          'endDate': endDate,
          'search': search,
          'deliverymanId': _currentUser.id, 
        },
      );

      return (response.data as List)
          .map((json) => Order.fromJson(json))
          .toList();

    } on DioException catch (e) {
      String message = e.response?.data['message'] ?? 'Échec de la récupération des commandes.';
      throw Exception(message);
    }
  }

  /// Récupère les compteurs de commandes par statut (pour la sidebar).
  Future<Map<String, int>> fetchOrderCounts() async {
    try {
      final response = await _dio.get('$_apiBaseUrl/counts', queryParameters: {
         'riderId': _currentUser.id,
      });

      final Map<String, dynamic> data = response.data;
      return data.map((key, value) => MapEntry(key, value as int));

    } on DioException catch (e) {
       String message = e.response?.data['message'] ?? 'Échec de la récupération des compteurs.';
       throw Exception(message);
    }
  }

  // --- Fonctions d'action (CRUD: PUT/POST avec Gestion Offline) ---
  
  // LOGIQUE OFFLINE : Gère la mise en file d'attente si hors ligne.
  Future<void> _handleOfflineRequest(String url, String method, Map<String, dynamic> payload, String baseErrorMessage) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      final request = SyncRequest(
        url: url,
        method: method,
        payload: jsonEncode(payload),
        token: _currentUser.token,
      );
      await _syncService.addRequest(request);
      throw Exception("Hors ligne. Action mise en file d'attente. Elle sera synchronisée dès que la connexion sera rétablie.");
    }
    throw Exception(baseErrorMessage);
  }

  /// Confirme la récupération physique du colis au Hub.
  Future<void> confirmPickup(int orderId) async {
    final String url = '$_apiBaseUrl/orders/$orderId/confirm-pickup-rider';
    try {
      await _dio.put(url);
    } on DioException catch (e) {
      final baseErrorMessage = e.response?.data['message'] ?? 'Échec de la confirmation de récupération.';
      await _handleOfflineRequest(url, 'PUT', {}, baseErrorMessage);
    }
  }
  
  /// Démarre la course après confirmation de la récupération.
  Future<void> startDelivery(int orderId) async {
    final String url = '$_apiBaseUrl/orders/$orderId/start-delivery';
    try {
      await _dio.put(url);
    } on DioException catch (e) {
      final baseErrorMessage = e.response?.data['message'] ?? 'Échec du démarrage de la course.';
      await _handleOfflineRequest(url, 'PUT', {}, baseErrorMessage);
    }
  }
  
  /// Met à jour le statut d'une commande (Livrée, Annulée, Ratée, Relance).
  Future<void> updateOrderStatus({
    required int orderId, 
    required String status, 
    String? paymentStatus, 
    double? amountReceived
  }) async {
    final payload = { 
      'status': status, 
      'payment_status': paymentStatus,
      'amount_received': amountReceived,
      'userId': _currentUser.id, 
    };
    final String url = "http://10.0.2.2:3000/api/orders/$orderId/status";
    
    try {
      await _dio.put(url, data: payload);
      
    } on DioException catch (e) {
      final baseErrorMessage = e.response?.data['message'] ?? 'Échec de la mise à jour du statut.';
      await _handleOfflineRequest(url, 'PUT', payload, baseErrorMessage);
    }
  }
  
  /// Déclare un colis comme retourné (passage en 'return_declared').
  Future<void> declareReturn(int orderId) async {
    final payload = {
        'comment': 'Déclaré depuis app Flutter',
        'userId': _currentUser.id,
    };
    final String url = "http://10.0.2.2:3000/api/orders/$orderId/declare-return";
    
    try {
      await _dio.post(url, data: payload);
    } on DioException catch (e) {
      final baseErrorMessage = e.response?.data['message'] ?? 'Échec de la déclaration de retour.';
      await _handleOfflineRequest(url, 'POST', payload, baseErrorMessage);
    }
  }
  
  /// Récupère les détails de la caisse pour une date donnée.
  Future<RiderCashDetails> fetchRiderCashDetails(DateTime date) async {
    try {
      final response = await _dio.get(
        '$_apiBaseUrl/cash-details', 
        queryParameters: {
          'riderId': _currentUser.id,
          'date': DateFormat('yyyy-MM-dd').format(date),
        },
      );

      return RiderCashDetails.fromJson(response.data);

    } on DioException catch (e) {
      String message = e.response?.data['message'] ?? 'Échec de la récupération de la caisse.';
      throw Exception(message);
    } catch (e) {
      throw Exception("Une erreur inattendue est survenue lors du chargement de la caisse.");
    }
  }
}
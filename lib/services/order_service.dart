// lib/services/order_service.dart

import 'package:dio/dio.dart';
import 'package:intl/intl.dart'; // <-- AJOUT NÉCESSAIRE
import '../models/order.dart';
import '../models/user.dart'; // Pour obtenir l'ID du Livreur
import '../models/rider_cash_details.dart'; // <-- AJOUT NÉCESSAIRE

class OrderService {
  final Dio _dio;
  final User _currentUser;
  // CORRECTION: Utilisation de l'IP spéciale pour l'émulateur Android
  static const String _apiBaseUrl = "http://10.0.2.2:3000/api/rider"; // Base API Livreur

  OrderService(this._dio, this._currentUser);

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
      final String statusQuery = statuses.join(','); // API attend une chaîne séparée par virgules pour les tableaux

      final response = await _dio.get(
        '$_apiBaseUrl/orders',
        queryParameters: {
          'status': statusQuery,
          'startDate': startDate,
          'endDate': endDate,
          'search': search,
          'deliverymanId': _currentUser.id, // S'assurer que l'ID est bien inclus dans les requêtes Livreur
        },
      );

      // Le backend renvoie une liste de maps JSON
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

  // --- Fonctions d'action (Confirmation, Début Course, Statut) ---
  
  /// Confirme la récupération physique du colis au Hub.
  Future<void> confirmPickup(int orderId) async {
    try {
      await _dio.put('$_apiBaseUrl/orders/$orderId/confirm-pickup-rider');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Échec de la confirmation de récupération.');
    }
  }
  
  /// Démarre la course après confirmation de la récupération.
  Future<void> startDelivery(int orderId) async {
    try {
      await _dio.put('$_apiBaseUrl/orders/$orderId/start-delivery');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Échec du démarrage de la course.');
    }
  }
  
  /// Met à jour le statut d'une commande (Livrée, Annulée, Ratée, Relance).
  Future<void> updateOrderStatus({
    required int orderId, 
    required String status, 
    String? paymentStatus, 
    double? amountReceived
  }) async {
    try {
      final payload = { 
        'status': status, 
        'payment_status': paymentStatus,
        'amount_received': amountReceived,
        'userId': _currentUser.id, // Nécessaire par le backend pour l'historique
      };
      
      // Note: l'endpoint utilise l'URL absolue (corrigée par _dio.options.baseUrl si configuré, sinon manuellement)
      // Cet appel utilise /api/orders, qui n'est pas préfixé par _apiBaseUrl. 
      // Il faut s'assurer que l'instance Dio a une baseUrl configurée ou le préfixer ici.
      // Pour la cohérence, je vais utiliser l'IP 10.0.2.2.
      await _dio.put('http://10.0.2.2:3000/api/orders/$orderId/status', data: payload);
      
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Échec de la mise à jour du statut.');
    }
  }
  
  /// Déclare un colis comme retourné (passage en 'return_declared').
  Future<void> declareReturn(int orderId) async {
    try {
      // De même ici, j'utilise l'IP 10.0.2.2
      await _dio.post('http://10.0.2.2:3000/api/orders/$orderId/declare-return', data: {'comment': 'Déclaré depuis app Flutter'});
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Échec de la déclaration de retour.');
    }
  }
  
  // --- MÉTHODE AJOUTÉE ---
  /// Récupère les détails de la caisse pour une date donnée.
  Future<RiderCashDetails> fetchRiderCashDetails(DateTime date) async {
    try {
      final response = await _dio.get(
        '$_apiBaseUrl/cash-details', // Endpoint supposé pour la caisse
        queryParameters: {
          'riderId': _currentUser.id,
          'date': DateFormat('yyyy-MM-dd').format(date),
        },
      );

      // Le backend renvoie l'objet RiderCashDetails
      return RiderCashDetails.fromJson(response.data);

    } on DioException catch (e) {
      String message = e.response?.data['message'] ?? 'Échec de la récupération de la caisse.';
      throw Exception(message);
    } catch (e) {
      // Attrape les erreurs de parsing ou autres
      throw Exception("Une erreur inattendue est survenue lors du chargement de la caisse.");
    }
  }
}
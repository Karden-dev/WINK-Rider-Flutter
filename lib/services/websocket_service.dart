// lib/services/websocket_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/order.dart'; 
import '../models/user.dart'; 
import 'notification_service.dart'; // <-- NOUVEL IMPORT

class WebSocketService extends ChangeNotifier {
  static const String _wsBaseUrl = "ws://10.0.2.2:3000"; 
  static const String _apiBaseUrl = "http://10.0.2.2:3000/api";
  
  final Dio _dio;
  final NotificationService _notificationService; // <-- AJOUTÉ
  User? _currentUser;
  
  WebSocketChannel? _channel;
  bool _isConnected = false;
  
  bool get isConnected => _isConnected;

  final StreamController<Map<String, dynamic>> _messageController = 
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messagesStream => _messageController.stream;
  
  final StreamController<String> _eventController = 
      StreamController<String>.broadcast();
  Stream<String> get eventStream => _eventController.stream;
  
  // CONSTRUCTEUR MIS À JOUR
  WebSocketService(this._dio, this._notificationService);

  // --- Gestion de la Connexion ---

  void connect(User user) {
    if (_isConnected && _channel != null) {
      debugPrint('WS: Déjà connecté.');
      _currentUser = user; 
      return;
    }
    
    _currentUser = user;
    final token = user.token;
    
    try {
      final wsUrl = Uri.parse('$_wsBaseUrl?token=$token');
      
      _channel = WebSocketChannel.connect(wsUrl);
      _isConnected = true;
      notifyListeners();

      _channel!.stream.listen(
        _onData,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: true,
      );
      
      debugPrint('WS: Tentative de connexion...');
      
    } catch (e) {
      debugPrint('WS: Erreur de connexion: $e');
      _isConnected = false;
      notifyListeners();
      Future.delayed(const Duration(seconds: 5), () => connect(user));
    }
  }
  
  void disconnect() {
    _channel?.sink.close(1000, 'Déconnexion manuelle');
    _isConnected = false;
    _channel = null;
    notifyListeners();
    debugPrint('WS: Déconnexion effectuée.');
  }

  // --- Gestion des Événements du Stream ---
  
  // ... _onData, _onError, _onDone inchangés (sauf pour l'appel à _handleInboundEvents) ...
  void _onData(dynamic data) {
    try {
      final Map<String, dynamic> message = jsonDecode(data);
      final type = message['type'] as String?;
      final payload = message['payload'] as Map<String, dynamic>?;

      if (type == null) return;
      
      debugPrint('WS: Message reçu - Type: $type');
      _messageController.add(message);
      _handleInboundEvents(type, payload);

    } catch (e) {
      debugPrint('WS: Erreur de parsing du message: $e, Data: $data');
    }
  }

  void _onError(Object error, StackTrace stackTrace) {
    debugPrint('WS: Erreur dans le stream: $error');
    _isConnected = false;
    notifyListeners();
    if (_currentUser != null) {
      Future.delayed(const Duration(seconds: 5), () => connect(_currentUser!));
    }
  }

  void _onDone() {
    debugPrint('WS: Connexion terminée par le serveur.');
    _isConnected = false;
    notifyListeners();
    if (_currentUser != null) {
      Future.delayed(const Duration(seconds: 5), () => connect(_currentUser!));
    }
  }

  void _handleInboundEvents(String type, Map<String, dynamic>? payload) {
    String? title;
    String? body;
    int notificationId = 0; // ID unique pour chaque type

    switch (type) {
      case 'NEW_ORDER_ASSIGNED':
        notificationId = 1;
        title = 'Nouvelle Commande Assignée !';
        body = 'Commande #${payload!['order_id']} (${payload['shop_name']}) est prête pour vous.';
        _eventController.add('ORDER_UPDATE');
        break;
        
      case 'ORDER_MARKED_URGENT':
         notificationId = 2;
         title = 'URGENCE !';
         body = 'Commande #${payload!['order_id']} marquée comme URGENTE par l\'admin.';
         _eventController.add('ORDER_UPDATE');
         break;
         
      case 'REMITTANCE_CONFIRMED':
         notificationId = 3;
         title = 'Versement Confirmé !';
         body = 'Votre versement a été confirmé par l\'administrateur.';
         _eventController.add('REMITTANCE_UPDATE');
         break;
         
      case 'NEW_MESSAGE':
        notificationId = 4;
        title = 'Nouveau Message !';
        body = payload!['message_content'] as String;
        _eventController.add('UNREAD_COUNT_UPDATE');
        break;
        
      case 'ORDER_STATUS_UPDATE':
      case 'CONVERSATION_LIST_UPDATE':
        _eventController.add('ORDER_UPDATE');
        break;
        
      default:
        return;
    }

    if (title != null && body != null) {
      _notificationService.showNotification(
        notificationId,
        title,
        body,
        payload: payload != null ? jsonEncode(payload) : null,
      );
    }
  }

  // ... Autres méthodes (send, join, leave, sendMessage, fetchMessages, fetchQuickReplies) inchangées ...
  
  void send(String type, {Map<String, dynamic>? payload}) {
    if (!_isConnected || _channel == null) {
      debugPrint('WS: Impossible d\'envoyer. Non connecté.');
      return;
    }
    final message = jsonEncode({'type': type, 'payload': payload});
    _channel!.sink.add(message);
  }
  
  void joinConversation(int orderId) {
    send('JOIN_CONVERSATION', payload: {'orderId': orderId});
  }
  
  void leaveConversation(int orderId) {
    send('LEAVE_CONVERSATION', payload: {'orderId': orderId});
  }
  
  Future<void> sendMessage(int orderId, String content) async {
    try {
      await _dio.post(
        '$_apiBaseUrl/orders/$orderId/messages',
        data: {'message_content': content},
      );
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Échec de l\'envoi du message.';
      throw Exception(message);
    }
  }

  Future<List<Map<String, dynamic>>> fetchMessages(int orderId, {int? lastMessageId}) async {
    try {
      final response = await _dio.get(
        '$_apiBaseUrl/orders/$orderId/messages',
        queryParameters: lastMessageId != null ? {'triggerRead': lastMessageId} : null,
      );
      return List<Map<String, dynamic>>.from(response.data);
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Échec du chargement de l\'historique.';
      throw Exception(message);
    }
  }
  
  Future<List<String>> fetchQuickReplies() async {
    try {
      final response = await _dio.get('$_apiBaseUrl/suivis/quick-replies');
      return List<String>.from(response.data);
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Échec du chargement des réponses rapides.';
      throw Exception(message);
    }
  }
}
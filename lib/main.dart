// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; 

// Correction des imports
import 'services/auth_service.dart';
import 'services/order_service.dart';
import 'services/websocket_service.dart'; 
import 'services/notification_service.dart'; 
import 'services/sync_service.dart';        // <-- Correction chemin
import 'models/sync_request.dart';        // <-- Ajout import manquant
import 'services/performance_service.dart'; 

import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'utils/app_theme.dart';

// Déclaration globale du NotificationService
final NotificationService _notificationService = NotificationService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await _notificationService.initialize();

  final authService = AuthService();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>(create: (context) => authService),
        
        // SyncService (Dépend de Dio, via AuthService)
        ProxyProvider<AuthService, SyncService?>(
          update: (context, auth, previousSyncService) {
            final dio = auth.dio;
            // Utilisation correcte du type SyncService
            final syncService = previousSyncService ?? SyncService(dio); 
            syncService.initializeConnectivityListener(); 
            return syncService;
          },
          lazy: false,
        ),
        
        // WebSocketService (Dépend d'AuthService et NotificationService)
        ProxyProvider<AuthService, WebSocketService?>(
          update: (context, auth, previousWebSocketService) {
            final dio = auth.dio;
            if (auth.isAuthenticated && auth.currentUser != null) {
              final wsService = previousWebSocketService ?? WebSocketService(dio, _notificationService); 
              if (!wsService.isConnected) { 
                wsService.connect(auth.currentUser!);
              }
              return wsService;
            }
            previousWebSocketService?.disconnect();
            return null;
          },
          lazy: false,
        ),
        
        // OrderService (Dépend d'AuthService et SyncService)
        ProxyProvider2<AuthService, SyncService?, OrderService?>(
          update: (context, auth, sync, previousOrderService) {
            if (auth.isAuthenticated && auth.currentUser != null && sync != null) {
              // Utilisation correcte du type SyncService
              return OrderService(auth.dio, auth.currentUser!, sync); 
            }
            return null;
          },
          lazy: true,
        ),
        
        // PerformanceService (Dépend d'AuthService)
        ProxyProvider<AuthService, PerformanceService?>(
          update: (context, auth, previousPerformanceService) {
            if (auth.isAuthenticated) {
              return PerformanceService(auth.dio); 
            }
            return null;
          },
          lazy: true,
        ),
      ],
      child: WinkRiderApp(authService: authService),
    ),
  );
}

class WinkRiderApp extends StatefulWidget {
  final AuthService authService;
  const WinkRiderApp({super.key, required this.authService});

  @override
  State<WinkRiderApp> createState() => _WinkRiderAppState();
}

class _WinkRiderAppState extends State<WinkRiderApp> {
  late Future<void> _initAuthFuture;

  @override
  void initState() {
    super.initState();
    _initAuthFuture = widget.authService.init();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WinkRiderApp',
      theme: AppTheme.lightTheme,
      home: FutureBuilder<void>(
        future: _initAuthFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (snapshot.hasError) {
             return Scaffold(
              body: Center(
                child: Text('Erreur au démarrage: ${snapshot.error}'),
              ),
            );
          }
          
          return Consumer<AuthService>(
            builder: (context, auth, child) {
              return auth.isAuthenticated ? const HomeScreen() : const LoginScreen();
            },
          );
        },
      ),
    );
  }
}
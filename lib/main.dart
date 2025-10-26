// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/order_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'utils/app_theme.dart';

void main() async {
  // Assure que les bindings Flutter sont initialisés pour les appels asynchrones (ex: SharedPreferences)
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialise l'AuthService et charge l'état de l'utilisateur (si token sauvegardé)
  final authService = AuthService();
  await authService.init();

  runApp(
    MultiProvider(
      // Configuration des fournisseurs d'état (Providers)
      providers: [
        // 1. AuthService : Fournit et notifie les changements d'état d'authentification
        ChangeNotifierProvider<AuthService>(create: (context) => authService),
        
        // 2. OrderService : Dépend du AuthService (pour le token et l'utilisateur courant)
        // OrderService n'a besoin d'être créé que si un utilisateur est authentifié.
        ProxyProvider<AuthService, OrderService?>(
          // Le type OrderService est rendu nullable (OrderService?) car il peut être null
          // avant l'authentification.
          update: (context, auth, previousOrderService) {
            // Crée le service seulement si l'utilisateur est connecté et le token est disponible
            if (auth.isAuthenticated && auth.currentUser != null) {
              // NOTE: Le code ci-dessous suppose que la classe AuthService a un getter 
              // public pour son instance de Dio (e.g. `Dio get dio => _dio;`).
              // Si ce n'est pas le cas, vous devez l'ajouter dans `auth_service.dart`.
              return OrderService(auth.dio, auth.currentUser!);
            }
            // Retourne null si l'utilisateur est déconnecté
            return null; 
          },
          lazy: true,
        ),
      ],
      child: const WinkRiderApp(),
    ),
  );
}

class WinkRiderApp extends StatelessWidget {
  const WinkRiderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WinkRiderApp',
      // Applique le thème défini
      theme: AppTheme.lightTheme,
      
      // Utilise Consumer pour écouter les changements d'état dans AuthService
      home: Consumer<AuthService>(
        builder: (context, auth, child) {
          // Redirige l'utilisateur vers l'écran d'accueil s'il est authentifié,
          // sinon vers l'écran de connexion.
          return auth.isAuthenticated ? const HomeScreen() : const LoginScreen();
        },
      ),
    );
  }
}
// lib/main.dart

import 'package:flutter/material.dart'; // CORRECTION: package.flutter -> package:flutter
import 'package:provider/provider.dart'; // Import essentiel ajouté
import '../services/auth_service.dart';
import '../services/order_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import '../utils/app_theme.dart';

void main() async {
  // Assure que les bindings Flutter sont initialisés
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise l'AuthService SANS l'attendre (await)
  final authService = AuthService();
  // Ne pas appeler await authService.init() ici. 
  // Nous allons le faire dans l'UI.

  runApp(
    MultiProvider(
      // Configuration des fournisseurs d'état (Providers)
      providers: [
        // 1. AuthService : Fournit et notifie les changements d'état d'authentification
        ChangeNotifierProvider<AuthService>(create: (context) => authService),

        // 2. OrderService : Dépend du AuthService (pour le token et l'utilisateur courant)
        ProxyProvider<AuthService, OrderService?>(
          update: (context, auth, previousOrderService) {
            if (auth.isAuthenticated && auth.currentUser != null) {
              return OrderService(auth.dio, auth.currentUser!);
            }
            return null;
          },
          lazy: true,
        ),
      ],
      // Nous passons l'instance d'authService à WinkRiderApp
      child: WinkRiderApp(authService: authService),
    ),
  );
}

class WinkRiderApp extends StatefulWidget {
  final AuthService authService;
  // Ajout d'un constructeur const
  const WinkRiderApp({super.key, required this.authService});

  @override
  State<WinkRiderApp> createState() => _WinkRiderAppState();
}

class _WinkRiderAppState extends State<WinkRiderApp> {
  // Future pour suivre l'état de l'initialisation
  late Future<void> _initAuthFuture;

  @override
  void initState() {
    super.initState();
    // Lance l'initialisation ici
    _initAuthFuture = widget.authService.init();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WinkRiderApp',
      theme: AppTheme.lightTheme,
      home: FutureBuilder<void>(
        // Nous attendons que l'initialisation (lecture du token) soit terminée
        future: _initAuthFuture,
        builder: (context, snapshot) {
          // Pendant le chargement (vérification du token...)
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          // Si erreur pendant l'init (rare, mais possible)
          if (snapshot.hasError) {
             return Scaffold(
              body: Center(
                child: Text('Erreur au démarrage: ${snapshot.error}'),
              ),
            );
          }

          // L'initialisation est terminée, nous utilisons le Consumer 
          // pour vérifier si l'utilisateur est authentifié
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
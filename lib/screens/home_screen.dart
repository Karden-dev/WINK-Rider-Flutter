// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async'; // Ajouté pour StreamSubscription

import '../services/auth_service.dart';
import '../services/order_service.dart';
import '../services/websocket_service.dart'; // Import du WebSocketService
import '../utils/app_theme.dart';

// --- IMPORTS DES ÉCRANS MIGRÉS ---
import 'orders_today_screen.dart';
import 'orders_history_screen.dart';
import 'orders_relaunch_screen.dart';
import 'riders_returns_screen.dart';
import 'rider_cash_screen.dart';
import 'rider_performance_screen.dart';
// --- FIN NOUVEAUX IMPORTS ---

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, int> _counts = {};
  bool _isLoadingCounts = true;
  int _selectedIndex = 0; // Index de la BottomNavigationBar

  StreamSubscription? _eventSubscription; // Pour le WebSocket

  // Liste des écrans principaux (pour la BottomNavigationBar)
  final List<Widget> _widgetOptions = <Widget>[
    const OrdersTodayScreen(),
    const OrdersHistoryScreen(),
    const RiderCashScreen(),
    const RiderPerformanceScreen(),
  ];

  // Liste des titres pour l'AppBar
  final List<String> _titles = <String>[
    'Courses du Jour',
    'Mes Courses (Historique)',
    'Ma Caisse',
    'Mes Performances',
  ];


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchCounts();
      _setupWebSocketListener(); // Configuration de l'écouteur WebSocket
    });
  }

  @override
  void dispose() {
    _eventSubscription?.cancel(); // Annuler la souscription
    super.dispose();
  }

  // --- LOGIQUE DE RAFRAÎCHISSEMENT EN TEMPS RÉEL ---
  void _setupWebSocketListener() {
    final wsService = Provider.of<WebSocketService?>(context, listen: false);
    if (wsService == null) return;

    _eventSubscription?.cancel();

    // Souscrire au flux d'événements
    _eventSubscription = wsService.eventStream.listen((event) {
      // Les événements critiques qui nécessitent une mise à jour des compteurs
      if (event == 'ORDER_UPDATE' || event == 'UNREAD_COUNT_UPDATE' || event == 'REMITTANCE_UPDATE') {
        _fetchCounts();
      }
    });
  }


  Future<void> _fetchCounts() async {
    if (!mounted) return;
    final orderService = Provider.of<OrderService?>(context, listen: false);

    if (orderService != null) {
      try {
        final counts = await orderService.fetchOrderCounts();
        if (mounted) {
          setState(() {
            _counts = counts;
            _isLoadingCounts = false;
          });
        }
      } catch (e) {
         if (mounted) {
            setState(() { _isLoadingCounts = false; });
         }
        debugPrint('Erreur chargement compteurs: $e');
      }
    } else {
        if (mounted) {
          setState(() { _isLoadingCounts = false; });
        }
    }
  }

  // Fonction utilitaire pour obtenir le nombre total des statuts "Aujourd'hui"
  int get _todayTotal {
    return (_counts['pending'] ?? 0) +
           (_counts['in_progress'] ?? 0) +
           (_counts['ready_for_pickup'] ?? 0) +
           (_counts['en_route'] ?? 0) +
           (_counts['reported'] ?? 0);
  }

  // Fonction de navigation BottomNavigationBar
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Forcer un fetch si on change de vue
    _fetchCounts();
  }


  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    if (authService.currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Calculs des compteurs pour l'affichage dans le Drawer / Badge
    final todayCount = _isLoadingCounts ? '0' : _todayTotal.toString();
    final relaunchCount = _isLoadingCounts ? '...' : (_counts['reported'] ?? 0).toString();
    final returnsCount = _isLoadingCounts ? '...' : ((_counts['return_declared'] ?? 0) + (_counts['returned'] ?? 0)).toString();
    final unreadMessageCount = (_counts['unread_messages'] ?? 0); // Compteur de messages non lus


    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchCounts, // Permet de rafraîchir les compteurs
          ),
          // Icône de Chat Global (Toujours présente pour les notifications non lues)
          IconButton(
            icon: Badge(
              isLabelVisible: unreadMessageCount > 0,
              label: Text(unreadMessageCount.toString()),
              child: const Icon(Icons.chat_bubble_outline),
            ),
            onPressed: () { /* TODO: Ouvrir l'écran de suivi/chat global */ },
          ),
          const SizedBox(width: 8),
        ],
      ),

      drawer: Drawer( // Menu latéral (pour les liens secondaires et déconnexion)
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(authService.currentUser!.name),
              accountEmail: Text(authService.currentUser!.phoneNumber),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.delivery_dining, color: AppTheme.primaryColor),
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
            ),

            // --- NAVIGATION SECONDAIRE (À relancer, Retours) ---
            ListTile(
              leading: const Icon(Icons.update),
              title: const Text('À relancer'),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(relaunchCount, style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => const OrdersRelaunchScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.assignment_return),
              title: const Text('Retours'),
               trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(returnsCount, style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => const OrdersReturnsScreen()));
              },
            ),

            const Spacer(), // Pousse la déconnexion en bas
            ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.danger),
              title: const Text('Déconnexion', style: TextStyle(color: AppTheme.danger)),
              onTap: () async {
                Navigator.of(context).pop();
                await authService.logout();
              },
            ),
          ],
        ),
      ),

      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex), // Affiche l'écran sélectionné
      ),

      // --- BottomNavigationBar pour la navigation principale ---
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.today),
                if (_todayTotal > 0 && !_isLoadingCounts)
                  Positioned(
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: AppTheme.danger,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(
                        todayCount,
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
              ],
            ),
            label: 'Aujourd\'hui',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Historique',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'Ma Caisse',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.leaderboard),
            label: 'Performances',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
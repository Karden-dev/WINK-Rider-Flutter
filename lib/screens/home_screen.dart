// lib/screens/home_screen.dart

import 'package:flutter/material.dart'; // CORRECTION : Import essentiel ajouté
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import '../utils/app_theme.dart';

// Utilise StatefulWidget pour pouvoir charger et afficher les compteurs
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> { // Utilise la classe State
  Map<String, int> _counts = {};
  bool _isLoadingCounts = true;

  @override
  void initState() {
    super.initState();
    // Lance le fetch des compteurs après le rendu initial pour avoir le BuildContext prêt.
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchCounts());
  }

  Future<void> _fetchCounts() async {
    // Écoute OrderService sans notifier le widget (listen: false)
    // S'assurer que le BuildContext est encore monté avant d'accéder au Provider
    if (!mounted) return;
    final orderService = Provider.of<OrderService?>(context, listen: false);

    if (orderService != null) {
      try {
        final counts = await orderService.fetchOrderCounts();
        // Vérifier à nouveau si le widget est monté avant d'appeler setState
        if (mounted) {
          setState(() { // Met à jour l'état local, reconstruit le widget
            _counts = counts;
            _isLoadingCounts = false;
          });
        }
      } catch (e) {
         if (mounted) {
            setState(() {
              _isLoadingCounts = false;
            });
         }
        // Utiliser debugPrint pour le développement Flutter
        debugPrint('Erreur chargement compteurs: $e');
        // Afficher une notification discrète à l'utilisateur si nécessaire
        // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur chargement des compteurs")));
      }
    } else {
        // Gérer le cas où OrderService est null (peut arriver brièvement lors de la déconnexion)
        debugPrint('OrderService non disponible lors du fetch des compteurs.');
        if (mounted) {
          setState(() { _isLoadingCounts = false; });
        }
    }
  }

  // Fonction utilitaire pour obtenir le nombre total des statuts "Aujourd'hui"
  int get _todayTotal {
    // Statuts pertinents pour "Aujourd'hui" basés sur rider-common.js
    return (_counts['pending'] ?? 0) +
           (_counts['in_progress'] ?? 0) +
           (_counts['ready_for_pickup'] ?? 0) +
           (_counts['en_route'] ?? 0) +
           (_counts['reported'] ?? 0);
  }


  @override
  Widget build(BuildContext context) {
    // Écoute AuthService pour afficher le nom de l'utilisateur et gérer la déconnexion
    final authService = Provider.of<AuthService>(context);

    // Sécurité : Si currentUser devient null (déconnexion en cours), afficher un chargement
    if (authService.currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Calculs des compteurs pour l'affichage (similaire à rider-common.js)
    final todayCount = _isLoadingCounts ? '...' : _todayTotal.toString();
    // Correction: fold ne fonctionne que si la liste n'est pas vide. Utiliser ?? 0.
    final myRidesCount = _isLoadingCounts ? '...' : (_counts.values.fold<int>(0, (sum, element) => sum + element)).toString();
    final relaunchCount = _isLoadingCounts ? '...' : (_counts['reported'] ?? 0).toString();
    final returnsCount = _isLoadingCounts ? '...' : ((_counts['return_declared'] ?? 0) + (_counts['returned'] ?? 0)).toString();


    return Scaffold(
      appBar: AppBar(
        title: const Text('WINK EXPRESS'),
        // automaticallyImplyLeading: false, // On laisse Flutter gérer le bouton du Drawer par défaut
      ),
      drawer: Drawer( // Menu latéral (Sidebar)
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(authService.currentUser!.name), // Null check fait plus haut
              accountEmail: Text(authService.currentUser!.phoneNumber), // Null check fait plus haut
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                // Utiliser une icône appropriée de Material Icons
                child: Icon(Icons.delivery_dining, color: AppTheme.primaryColor),
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
            ),

            // --- ÉLÉMENTS DE MENU AVEC COMPTEURS (Basé sur rider-today.html) ---
            ListTile(
              leading: const Icon(Icons.today),
              title: const Text('Courses du Jour'),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(todayCount, style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
              onTap: () {
                // TODO: Naviguer vers l'écran des courses du jour
                Navigator.of(context).pop(); // Ferme le drawer
              },
            ),
            ListTile(
              leading: const Icon(Icons.list_alt),
              title: const Text('Mes courses'),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(myRidesCount, style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
              onTap: () {
                // TODO: Naviguer vers l'écran de l'historique des courses
                Navigator.of(context).pop();
              },
            ),
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
                // TODO: Naviguer vers l'écran de relance
                Navigator.of(context).pop();
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
                // TODO: Naviguer vers l'écran des retours
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              // CORRECTION : Icône valide pour 'Ma Caisse'
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: const Text('Ma caisse'),
              onTap: () {
                // TODO: Naviguer vers l'écran de caisse
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.leaderboard),
              title: const Text('Mes Performances'),
              onTap: () {
                // TODO: Naviguer vers l'écran de performance
                Navigator.of(context).pop();
              },
            ),
            // --- FIN DES ÉLÉMENTS DE MENU ---

            const Spacer(), // Pousse la déconnexion en bas
            ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.danger),
              title: const Text('Déconnexion', style: TextStyle(color: AppTheme.danger)),
              onTap: () async {
                Navigator.of(context).pop(); // Ferme le drawer avant la déconnexion
                await authService.logout();
                // La redirection est gérée par le Consumer dans main.dart
              },
            ),
          ],
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Bienvenue, ${authService.currentUser?.name ?? 'Livreur'}!', // Plus sûr avec '?.'
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const Text(
                'Sélectionnez une option dans le menu pour commencer votre journée de livraison.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () {
                  Scaffold.of(context).openDrawer(); // Ouvre le Drawer
                },
                icon: const Icon(Icons.menu),
                label: const Text('Ouvrir le Menu'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  backgroundColor: Theme.of(context).primaryColor, // Couleur Corail
                  foregroundColor: Colors.white, // Texte en blanc
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
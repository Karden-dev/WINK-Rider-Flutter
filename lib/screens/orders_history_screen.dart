// lib/screens/orders_history_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../services/order_service.dart';
import '../models/order.dart';
import '../utils/app_theme.dart';
// Importe le widget OrderCard que nous avons créé précédemment
import 'orders_today_screen.dart' show OrderCard; // Importe seulement OrderCard

class OrdersHistoryScreen extends StatefulWidget {
  const OrdersHistoryScreen({super.key});

  @override
  State<OrdersHistoryScreen> createState() => _OrdersHistoryScreenState();
}

class _OrdersHistoryScreenState extends State<OrdersHistoryScreen> {
  Future<List<Order>>? _ordersFuture; // Nullable pour le chargement initial différé

  // Contrôleurs pour les champs de filtre
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  // Variables pour stocker les filtres actuels
  String? _searchQuery;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    // Définit la plage de dates par défaut (aujourd'hui) et lance le premier fetch
    _setInitialDatesAndFetch();
  }

  void _setInitialDatesAndFetch() {
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day); // Début de journée
    _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59); // Fin de journée
    _startDateController.text = DateFormat('dd/MM/yyyy').format(_startDate!);
    _endDateController.text = DateFormat('dd/MM/yyyy').format(_endDate!);
    // Lance le premier fetch
     WidgetsBinding.instance.addPostFrameCallback((_) {
         _fetchOrders();
     });
  }


  // Fonction pour récupérer les commandes en fonction des filtres
  Future<void> _fetchOrders() async {
    final orderService = Provider.of<OrderService?>(context, listen: false);
    if (orderService == null) {
       // Affiche une erreur si le service n'est pas disponible
       setState(() {
         _ordersFuture = Future.error("Service de commandes non disponible.");
       });
       return;
    }

    // Met à jour l'état pour afficher le spinner et lancer l'appel API
    setState(() {
      _ordersFuture = orderService.fetchRiderOrders(
        statuses: ['all'], // Récupère tous les statuts pour l'historique
        startDate: _startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : null,
        endDate: _endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : null,
        search: _searchQuery,
      );
    });
  }

  // Fonction pour afficher le sélecteur de date
  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: (isStartDate ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime(2020), // Date de début raisonnable
      lastDate: DateTime.now().add(const Duration(days: 365)), // Date de fin raisonnable
      locale: const Locale('fr', 'FR'), // Met le calendrier en Français
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = DateTime(picked.year, picked.month, picked.day); // Début de journée
          _startDateController.text = DateFormat('dd/MM/yyyy').format(_startDate!);
        } else {
           _endDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59); // Fin de journée
          _endDateController.text = DateFormat('dd/MM/yyyy').format(_endDate!);
        }
        // Optionnel: Déclencher automatiquement le fetch après sélection de date
        // _fetchOrders();
      });
    }
  }

  // Fonction appelée lors du clic sur le bouton "Filtrer"
  void _applyFilters() {
     setState(() {
       _searchQuery = _searchController.text.trim().isEmpty ? null : _searchController.text.trim();
       // Les dates sont déjà mises à jour par _selectDate
     });
    _fetchOrders(); // Relance le fetch avec les nouveaux filtres
  }

  @override
  void dispose() {
    _searchController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Courses (Historique)'),
      ),
      body: Column(
        children: [
          // --- Section des Filtres ---
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                // Champ de recherche
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Rechercher (ID, Client, Lieu...)',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _applyFilters(); // Appliquer le filtre vide
                          },
                        )
                      : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  ),
                   onSubmitted: (_) => _applyFilters(), // Filtrer en appuyant sur Entrée
                ),
                const SizedBox(height: 10),
                // Champs de date
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _startDateController,
                        decoration: InputDecoration(
                          labelText: 'Du',
                          prefixIcon: const Icon(Icons.calendar_today),
                           border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                           contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        ),
                        readOnly: true,
                        onTap: () => _selectDate(context, true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _endDateController,
                        decoration: InputDecoration(
                          labelText: 'Au',
                          prefixIcon: const Icon(Icons.calendar_today),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        ),
                        readOnly: true,
                        onTap: () => _selectDate(context, false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Bouton Filtrer
                    ElevatedButton(
                      onPressed: _applyFilters,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                      ),
                      child: const Icon(Icons.filter_list),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // --- Section Liste des Commandes ---
          Expanded(
            child: FutureBuilder<List<Order>>(
              future: _ordersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Erreur: ${snapshot.error.toString().replaceFirst('Exception: ', '')}',
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      'Aucune commande trouvée pour ces filtres.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                final orders = snapshot.data!;
                // Tri antichronologique pour l'historique
                orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

                return ListView.builder(
                  padding: const EdgeInsets.only(left: 12.0, right: 12.0, bottom: 12.0),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    // Réutilise le même widget OrderCard
                    return OrderCard(order: orders[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
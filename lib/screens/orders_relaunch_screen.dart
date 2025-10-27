// lib/screens/orders_relaunch_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../services/order_service.dart';
import '../models/order.dart';
import '../utils/app_theme.dart';
// Importe le widget OrderCard
import 'orders_today_screen.dart' show OrderCard;

class OrdersRelaunchScreen extends StatefulWidget {
  const OrdersRelaunchScreen({super.key});

  @override
  State<OrdersRelaunchScreen> createState() => _OrdersRelaunchScreenState();
}

class _OrdersRelaunchScreenState extends State<OrdersRelaunchScreen> {
  Future<List<Order>>? _ordersFuture;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  String? _searchQuery;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    // Définit la plage de dates par défaut (7 derniers jours) et lance le fetch
    _setInitialDatesAndFetch();
  }

  void _setInitialDatesAndFetch() {
    final now = DateTime.now();
    // Défaut: 7 derniers jours (comme dans la PWA rider.js)
    _startDate = now.subtract(const Duration(days: 6)).copyWith(hour: 0, minute: 0, second: 0, millisecond: 0);
    _endDate = now.copyWith(hour: 23, minute: 59, second: 59, millisecond: 999);
    _startDateController.text = DateFormat('dd/MM/yyyy', 'fr_FR').format(_startDate!);
    _endDateController.text = DateFormat('dd/MM/yyyy', 'fr_FR').format(_endDate!);
    // Lance le premier fetch après le build initial
     WidgetsBinding.instance.addPostFrameCallback((_) {
         _fetchOrders();
     });
  }

  Future<void> _fetchOrders() async {
    final orderService = Provider.of<OrderService?>(context, listen: false);
     if (orderService == null) {
       setState(() {
         _ordersFuture = Future.error("Service de commandes non disponible.");
       });
       return;
    }

    setState(() {
      _ordersFuture = orderService.fetchRiderOrders(
        statuses: ['reported'], // Filtre spécifique pour cet écran
        startDate: _startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : null,
        endDate: _endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : null,
        search: _searchQuery,
      );
    });
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: (isStartDate ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('fr', 'FR'),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = DateTime(picked.year, picked.month, picked.day);
          _startDateController.text = DateFormat('dd/MM/yyyy', 'fr_FR').format(_startDate!);
        } else {
           _endDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
          _endDateController.text = DateFormat('dd/MM/yyyy', 'fr_FR').format(_endDate!);
        }
      });
    }
  }

  void _applyFilters() {
     setState(() {
       _searchQuery = _searchController.text.trim().isEmpty ? null : _searchController.text.trim();
     });
    _fetchOrders();
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
        title: const Text('Commandes à Relancer'),
      ),
      body: Column(
        children: [
          // --- Section des Filtres (Identique à l'historique) ---
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
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
                            _applyFilters();
                          },
                        )
                      : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  ),
                   onSubmitted: (_) => _applyFilters(),
                ),
                const SizedBox(height: 10),
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
                      'Aucune commande à relancer trouvée.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                final orders = snapshot.data!;
                 // Tri antichronologique pour la relance aussi
                orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

                return ListView.builder(
                  padding: const EdgeInsets.only(left: 12.0, right: 12.0, bottom: 12.0),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
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
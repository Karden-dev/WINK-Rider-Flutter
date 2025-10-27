// lib/screens/orders_today_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // Pour le formatage des dates et montants

import '../services/order_service.dart';
import '../models/order.dart';
import '../utils/app_theme.dart'; // Pour les couleurs
// Import de l'écran de détails
import 'order_details_screen.dart'; // <-- AJOUTÉ

class OrdersTodayScreen extends StatefulWidget {
  const OrdersTodayScreen({super.key});

  @override
  State<OrdersTodayScreen> createState() => _OrdersTodayScreenState();
}

class _OrdersTodayScreenState extends State<OrdersTodayScreen> {
  late Future<List<Order>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    // Lance le fetch des commandes dès l'initialisation de l'écran
    _ordersFuture = _fetchOrders();
  }

  Future<List<Order>> _fetchOrders() async {
    // Utilise le OrderService via Provider pour récupérer les données
    final orderService = Provider.of<OrderService?>(context, listen: false);
    if (orderService == null) {
      // Gérer le cas où le service n'est pas encore prêt (peut arriver brièvement)
      await Future.delayed(const Duration(milliseconds: 100)); // Attendre un peu
      if (!mounted) return []; // Vérifier si le widget est toujours là
      final orderServiceRetry = Provider.of<OrderService?>(context, listen: false);
       if (orderServiceRetry == null) {
          throw Exception("Service de commandes non disponible.");
       }
       return orderServiceRetry.fetchRiderOrders(
          statuses: ['pending', 'in_progress', 'ready_for_pickup', 'en_route', 'reported'],
          startDate: DateFormat('yyyy-MM-dd').format(DateTime.now()), // Date du jour
          endDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),   // Date du jour
       );
    }
    // Statuts pour "Aujourd'hui" basés sur rider.js
    return orderService.fetchRiderOrders(
      statuses: ['pending', 'in_progress', 'ready_for_pickup', 'en_route', 'reported'],
      startDate: DateFormat('yyyy-MM-dd').format(DateTime.now()), // Date du jour
      endDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),   // Date du jour
    );
  }

  // Fonction pour rafraîchir la liste (Pull-to-refresh)
  Future<void> _refreshOrders() async {
    setState(() {
      _ordersFuture = _fetchOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Courses du Jour'),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshOrders, // Active le pull-to-refresh
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
                  'Aucune commande pour aujourd\'hui.',
                  style: TextStyle(color: Colors.grey),
                ),
              );
            }

            final orders = snapshot.data!;
            // Tri des commandes (optionnel, similaire à rider-common.js)
            // orders.sort((a, b) => /* Logique de tri complexe ici si nécessaire */);

            return ListView.builder(
              padding: const EdgeInsets.all(12.0), // Espace autour de la liste
              itemCount: orders.length,
              itemBuilder: (context, index) {
                return OrderCard(order: orders[index]); // Utilise le widget OrderCard
              },
            );
          },
        ),
      ),
    );
  }
}

// --- WIDGET POUR AFFICHER UNE CARTE DE COMMANDE (Réutilisée par d'autres écrans) ---

class OrderCard extends StatelessWidget {
  final Order order;

  const OrderCard({super.key, required this.order});

  // Helper pour obtenir la couleur du statut
  Color _getStatusColor(String status) {
    switch (status) {
      case 'delivered': return Colors.green.shade700;
      case 'cancelled': case 'failed_delivery': case 'return_declared': case 'returned': return Colors.red.shade700;
      case 'pending': return Colors.orange.shade700;
      case 'in_progress': case 'ready_for_pickup': return Colors.blue.shade700;
      case 'en_route': return AppTheme.primaryColor; // Corail
      case 'reported': return Colors.purple.shade700;
      default: return Colors.grey.shade700;
    }
  }

  // Helper pour obtenir l'icône du statut
  IconData _getStatusIcon(String status) {
     switch (status) {
      case 'delivered': return Icons.check_circle_outline;
      case 'cancelled': return Icons.cancel_outlined;
      case 'failed_delivery': return Icons.error_outline;
      case 'return_declared': case 'returned': return Icons.assignment_return_outlined;
      case 'pending': return Icons.pending_outlined;
      case 'in_progress': return Icons.assignment_ind_outlined;
      case 'ready_for_pickup': return Icons.inventory_2_outlined;
      case 'en_route': return Icons.local_shipping_outlined;
      case 'reported': return Icons.report_problem_outlined;
      default: return Icons.help_outline;
    }
  }

  // Fonction pour gérer les clics sur les actions du menu (simplifiée pour l'exemple)
  void _handleMenuAction(BuildContext context, String action) {
     if (action == 'call_client') {
       // TODO: Implémenter l'appel
        debugPrint('Appel du client : ${order.customerPhone}');
     } else if (action == 'status') {
       // TODO: Ouvrir modale de changement de statut
        debugPrint('Ouverture modale statut pour Cde ${order.id}');
     }
      // Ajoutez ici d'autres logiques d'action...
  }


  @override
  Widget build(BuildContext context) {
    final orderService = Provider.of<OrderService?>(context, listen: false); // Pour les traductions
    final statusText = orderService?.statusTranslations[order.status] ?? order.status;
    final statusColor = _getStatusColor(order.status);
    final statusIcon = _getStatusIcon(order.status);
    final amountToCollectFormatted = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0).format(order.amountToCollect);

    return GestureDetector( // Rendre la carte cliquable
       onTap: () {
         Navigator.of(context).push(MaterialPageRoute(
           builder: (context) => OrderDetailsScreen(order: order), // Navigation vers l'écran de détails
         ));
       },
       child: Card(
         elevation: 3, // Légère ombre
         margin: const EdgeInsets.only(bottom: 12.0), // Espace entre les cartes
         shape: RoundedRectangleBorder(
           borderRadius: BorderRadius.circular(12.0), // Coins arrondis
           side: order.isUrgent ? const BorderSide(color: AppTheme.danger, width: 2) : BorderSide.none, // Bordure rouge si urgent
         ),
         child: Padding(
           padding: const EdgeInsets.all(16.0),
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               // --- Header de la carte ---
               Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Text(
                     'Commande #${order.id}',
                     style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                   ),
                   // Actions (Chat, Options, Contact)
                   Row(
                     children: [
                       IconButton(
                         icon: Badge(
                           label: Text(order.unreadCount.toString()),
                           isLabelVisible: order.unreadCount > 0,
                           child: const Icon(Icons.chat_bubble_outline),
                         ),
                         color: AppTheme.secondaryColor,
                         tooltip: 'Discussion',
                         onPressed: () { /* TODO: Ouvrir écran/modale chat */ },
                       ),
                       PopupMenuButton<String>(
                         icon: const Icon(Icons.more_vert, color: AppTheme.secondaryColor),
                         tooltip: 'Options',
                         onSelected: (String result) => _handleMenuAction(context, result),
                         itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                           // --- AJOUTER LES ACTIONS POSSIBLES ICI ---
                           if (order.status == 'ready_for_pickup' && !order.isPickedUp)
                             const PopupMenuItem<String>(value: 'pickup', child: ListTile(leading: Icon(Icons.inventory), title: Text('Confirmer Récupération'))),
                           if (order.status == 'ready_for_pickup' && order.isPickedUp)
                             const PopupMenuItem<String>(value: 'start_delivery', child: ListTile(leading: Icon(Icons.play_circle_outline), title: Text('Démarrer Course'))),
                           if (['en_route', 'reported'].contains(order.status)) // Statuer si en route ou relance
                             const PopupMenuItem<String>(value: 'status', child: ListTile(leading: Icon(Icons.check_circle_outline), title: Text('Statuer la commande'))),
                           if (['en_route', 'failed_delivery', 'cancelled', 'reported'].contains(order.status)) // Retour si statut compatible
                             const PopupMenuItem<String>(value: 'return', child: ListTile(leading: Icon(Icons.assignment_return), title: Text('Déclarer un retour'))),
                           if (order.status == 'ready_for_pickup' || ['en_route', 'failed_delivery', 'cancelled', 'reported'].contains(order.status))
                              const PopupMenuDivider(),
                           const PopupMenuItem<String>(value: 'call_client', child: ListTile(leading: Icon(Icons.call), title: Text('Appeler Client'))),
                         ],
                       ),
                     ],
                   ),
                 ],
               ),
               const Divider(height: 16),

               // --- Détails de la commande ---
               _buildDetailRow(Icons.storefront, 'Marchand', order.shopName),
               _buildDetailRow(Icons.person_outline, 'Client', order.customerName ?? order.customerPhone),
               _buildDetailRow(Icons.location_on_outlined, 'Adresse', order.deliveryLocation),
               _buildDetailRow(Icons.list_alt, 'Articles', order.itemsList ?? 'Non spécifié', maxLines: 2),

               const SizedBox(height: 8),
               // --- Statut & Montant ---
               Row(
                 children: [
                    Icon(statusIcon, color: statusColor, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                         statusText,
                         style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                    // Montant à encaisser
                    Text(
                      amountToCollectFormatted,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.primaryColor, // Couleur Corail
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                 ],
               ),

                // Date de création
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Créée le ${DateFormat('dd MMM yyyy à HH:mm', 'fr_FR').format(order.createdAt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    textAlign: TextAlign.right,
                  ),
                ),
             ],
           ),
         ),
       ),
    );
  }

  // Widget helper pour afficher une ligne de détail avec icône
  Widget _buildDetailRow(IconData icon, String label, String value, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$label: ', // Ajout du label ici
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              overflow: TextOverflow.ellipsis,
              maxLines: maxLines,
            ),
          ),
           Expanded( // Valeur prend le reste de l'espace
            flex: 2, // Donne plus de place à la valeur
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              overflow: TextOverflow.ellipsis,
              maxLines: maxLines,
            ),
          ),
        ],
      ),
    );
  }
}
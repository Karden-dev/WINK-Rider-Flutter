// lib/screens/order_details_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Pour le formatage
import 'package:provider/provider.dart'; // Pour accéder aux traductions

import '../models/order.dart';
import '../services/order_service.dart'; // Pour les traductions
import '../utils/app_theme.dart';

class OrderDetailsScreen extends StatelessWidget {
  final Order order;

  const OrderDetailsScreen({super.key, required this.order});

  // --- Fonctions Helper pour le formatage et l'affichage ---

  // Formatteur de devise
  String _formatAmount(double amount) {
    return NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0).format(amount);
  }

  // Formatteur de date et heure
  String _formatDateTime(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(dateTime);
  }

  // Widget pour afficher une ligne de détail (icône, label, valeur)
  Widget _buildDetailRow(BuildContext context, IconData icon, String label, String value, {int maxLines = 1, TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Text('$label:', style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: valueStyle ?? const TextStyle(fontWeight: FontWeight.w500),
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Widget pour afficher le statut avec couleur et icône
  Widget _buildStatusBadge(BuildContext context, Order order) {
    // Récupère les traductions et couleurs depuis OrderService (similaire à OrderCard)
    final orderService = Provider.of<OrderService?>(context, listen: false);
    final statusText = orderService?.statusTranslations[order.status] ?? order.status;
    final paymentText = orderService != null ? (paymentTranslations[order.paymentStatus] ?? order.paymentStatus) : order.paymentStatus; // Utilise la map locale

    // Logique de couleur/icône similaire à OrderCard mais à adapter si besoin
    final statusColor = _getStatusColor(order.status);
    final statusIcon = _getStatusIcon(order.status);
    final paymentColor = _getPaymentColor(order.paymentStatus);
    final paymentIcon = _getPaymentIcon(order.paymentStatus);


    return Column(
      children: [
         Row(
           children: [
             Icon(statusIcon, color: statusColor, size: 18),
             const SizedBox(width: 8),
             Text('Statut:', style: TextStyle(color: Colors.grey.shade700)),
             const SizedBox(width: 8),
             Expanded(child: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold))),
           ],
         ),
         const SizedBox(height: 6),
         Row(
           children: [
             Icon(paymentIcon, color: paymentColor, size: 18),
             const SizedBox(width: 8),
             Text('Paiement:', style: TextStyle(color: Colors.grey.shade700)),
             const SizedBox(width: 8),
             Expanded(child: Text(paymentText, style: TextStyle(color: paymentColor, fontWeight: FontWeight.bold))),
           ],
         ),
         if (order.status == 'failed_delivery' && order.amountReceived != null && order.amountReceived! > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Row(
                 children: [
                   const Icon(Icons.attach_money, size: 18, color: Colors.orange),
                   const SizedBox(width: 8),
                   Text('Montant Reçu (Échec):', style: TextStyle(color: Colors.grey.shade700)),
                   const SizedBox(width: 8),
                    Expanded(child: Text(_formatAmount(order.amountReceived!), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange))),
                 ],
              ),
            ),
      ],
    );
  }


   // Map de traduction de paiement (localement car non dans OrderService)
   static const Map<String, String> paymentTranslations = {
    'pending': 'En attente',
    'cash': 'En espèces',
    'paid_to_supplier': 'Mobile Money',
    'cancelled': 'Annulé'
   };

    // --- Helpers pour couleurs/icônes (similaires à OrderCard) ---
    Color _getStatusColor(String status) {
      switch (status) {
        case 'delivered': return Colors.green.shade700;
        case 'cancelled': case 'failed_delivery': case 'return_declared': case 'returned': return AppTheme.danger;
        case 'pending': return Colors.orange.shade700;
        case 'in_progress': case 'ready_for_pickup': return Colors.blue.shade700;
        case 'en_route': return AppTheme.primaryColor;
        case 'reported': return Colors.purple.shade700;
        default: return Colors.grey.shade700;
      }
    }

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

    Color _getPaymentColor(String paymentStatus) {
      switch (paymentStatus) {
        case 'pending': return Colors.orange.shade700;
        case 'cash': return Colors.green.shade700;
        case 'paid_to_supplier': return Colors.blue.shade700;
        case 'cancelled': return AppTheme.danger;
        default: return Colors.grey.shade700;
      }
    }

     IconData _getPaymentIcon(String paymentStatus) {
      switch (paymentStatus) {
        case 'pending': return Icons.hourglass_empty;
        case 'cash': return Icons.money;
        case 'paid_to_supplier': return Icons.phone_android;
        case 'cancelled': return Icons.money_off;
        default: return Icons.help_outline;
      }
    }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Détails Commande #${order.id}'),
        // On pourrait ajouter des actions ici (Modifier, etc.) si l'admin a les droits
      ),
      body: ListView( // Utilise ListView pour permettre le défilement si le contenu est long
        padding: const EdgeInsets.all(16.0),
        children: [
          // --- Section Informations Générales ---
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Informations Générales', style: Theme.of(context).textTheme.titleLarge),
                  const Divider(height: 20),
                  _buildDetailRow(context, Icons.storefront, 'Marchand', order.shopName),
                  _buildDetailRow(context, Icons.person, 'Client', order.customerName ?? 'N/A'),
                  _buildDetailRow(context, Icons.phone, 'Téléphone Client', order.customerPhone),
                  _buildDetailRow(context, Icons.location_on, 'Lieu Livraison', order.deliveryLocation, maxLines: 2),
                  _buildDetailRow(context, Icons.person_pin_circle_outlined, 'Livreur', order.deliverymanName ?? 'Non assigné'),
                  _buildDetailRow(context, Icons.calendar_today, 'Date Création', _formatDateTime(order.createdAt)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // --- Section Montants et Statuts ---
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Montants et Statuts', style: Theme.of(context).textTheme.titleLarge),
                  const Divider(height: 20),
                  _buildDetailRow(context, Icons.receipt_long, 'Montant Articles', _formatAmount(order.articleAmount), valueStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.secondaryColor)),
                  _buildDetailRow(context, Icons.local_shipping, 'Frais Livraison', _formatAmount(order.deliveryFee)),
                  // Ajout des frais d'expédition si > 0 (comme dans orders.js)
                  // if (order.expeditionFee > 0)
                  //   _buildDetailRow(context, Icons.flight_takeoff, 'Frais Expédition', _formatAmount(order.expeditionFee)),
                  const SizedBox(height: 10),
                  _buildStatusBadge(context, order),

                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // --- Section Articles ---
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text('Articles Commandés', style: Theme.of(context).textTheme.titleLarge),
                   const Divider(height: 20),
                  // TODO: Itérer sur la liste d'articles si elle existe dans le modèle Order
                  // Pour l'instant, on affiche itemsList s'il existe
                  Text(order.itemsList ?? 'Aucun détail d\'article disponible.'),
                   // Alternative si on avait une vraie liste d'OrderItem dans le modèle Order:
                  // if (order.items != null && order.items!.isNotEmpty)
                  //   ...order.items!.map((item) => ListTile(
                  //     leading: CircleAvatar(child: Text(item.quantity.toString())),
                  //     title: Text(item.itemName),
                  //     trailing: Text(_formatAmount(item.amount * item.quantity)),
                  //   )).toList()
                  // else
                  //   const Text('Aucun détail d\'article disponible.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // --- Section Historique ---
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Historique', style: Theme.of(context).textTheme.titleLarge),
                  const Divider(height: 20),
                  // TODO: Charger et afficher l'historique de la commande
                  // Cela nécessitera probablement un appel API supplémentaire dans OrderService
                  // et l'affichage des résultats ici (peut-être avec un FutureBuilder interne).
                  const Text('Section historique à implémenter.'),
                  // Exemple d'affichage si on avait une liste `history` :
                  // Column(
                  //   children: order.history.map((hist) => ListTile(
                  //       leading: Icon(Icons.history),
                  //       title: Text(hist.action),
                  //       subtitle: Text('${_formatDateTime(hist.createdAt)} par ${hist.userName}'),
                  //   )).toList(),
                  // ),
                ],
              ),
            ),
          ),
        ],
      ),
       // FloatingActionButton pour les actions rapides ? (Optionnel)
       // floatingActionButton: FloatingActionButton.extended(
       //   onPressed: () { /* Ouvrir le chat ? */ },
       //   label: const Text('Chat'),
       //   icon: const Icon(Icons.chat),
       // ),
    );
  }
}
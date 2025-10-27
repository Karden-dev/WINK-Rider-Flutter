// lib/screens/rider_cash_screen.dart

import 'package:flutter/material.dart'; // <-- CORRECTION: 'package:' au lieu de 'package.'
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/order_service.dart';
import '../models/rider_cash_details.dart';
import '../utils/app_theme.dart';

class RiderCashScreen extends StatefulWidget {
  const RiderCashScreen({super.key});

  @override
  State<RiderCashScreen> createState() => _RiderCashScreenState();
}

class _RiderCashScreenState extends State<RiderCashScreen> {
  DateTime _selectedDate = DateTime.now();
  Future<RiderCashDetails>? _cashDetailsFuture;

  @override
  void initState() {
    super.initState();
    _fetchDetailsForSelectedDate(); // Charge les détails pour aujourd'hui initialement
  }

  void _fetchDetailsForSelectedDate() {
    final orderService = Provider.of<OrderService?>(context, listen: false);
    if (orderService == null) {
      // Afficher une erreur si le service n'est pas disponible
      setState(() {
        _cashDetailsFuture = Future.error("Service non disponible.");
      });
      return;
    }
    setState(() {
      _cashDetailsFuture = orderService.fetchRiderCashDetails(_selectedDate);
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020), // Ajustez si nécessaire
      lastDate: DateTime.now().add(const Duration(days: 1)), // Permet de sélectionner demain au max
      locale: const Locale('fr', 'FR'),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchDetailsForSelectedDate(); // Recharge les données pour la nouvelle date
    }
  }

  // --- Widgets pour l'UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ma Caisse'),
      ),
      body: Column(
        children: [
          // --- Sélecteur de Date ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Affichage pour le:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(_selectedDate),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _selectDate(context),
                ),
              ],
            ),
          ),

          // --- Résumé Financier ---
          FutureBuilder<RiderCashDetails>(
            future: _cashDetailsFuture,
            builder: (context, snapshot) {
              // Affiche seulement le résumé une fois les données chargées
              if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                final summary = snapshot.data!.summary;
                return _buildSummaryCard(summary);
              }
              // Affiche un placeholder pendant le chargement initial ou en cas d'erreur
              return _buildSummaryCard(null, snapshot.hasError);
            },
          ),

          // --- Titre Liste Transactions ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Text(
              'Détail des Transactions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),

          // --- Liste des Transactions ---
          Expanded(
            child: FutureBuilder<RiderCashDetails>(
              future: _cashDetailsFuture,
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
                } else if (!snapshot.hasData || snapshot.data!.transactions.isEmpty) {
                  return const Center(
                    child: Text(
                      'Aucune transaction pour cette date.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                final transactions = snapshot.data!.transactions;

                return ListView.separated(
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final tx = transactions[index];
                    if (tx is OrderTransaction) {
                      return _buildOrderTransactionItem(tx);
                    } else if (tx is ExpenseTransaction) {
                      return _buildExpenseTransactionItem(tx);
                    } else if (tx is ShortfallTransaction) {
                      return _buildShortfallTransactionItem(tx);
                    }
                    return const SizedBox.shrink(); // Ne devrait pas arriver
                  },
                  separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Widget pour la carte de résumé
  Widget _buildSummaryCard(CashSummary? summary, [bool hasError = false]) {
    bool isLoading = summary == null && !hasError;
    String expected = isLoading ? 'Chargement...' : formatAmount(summary!.amountExpected);
    String confirmed = isLoading ? 'Chargement...' : formatAmount(summary!.amountConfirmed);
    String expenses = isLoading ? 'Chargement...' : formatAmount(summary!.totalExpenses);

    if (hasError) {
        expected = 'Erreur';
        confirmed = 'Erreur';
        expenses = 'Erreur';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSummaryRow(
              'Montant Attendu',
              expected,
              hasError ? Colors.red : AppTheme.primaryColor,
              isLoading,
            ),
            const Divider(height: 16),
            _buildSummaryRow(
              'Versements Confirmés',
              confirmed,
              hasError ? Colors.red : Colors.green.shade700,
              isLoading,
            ),
             const Divider(height: 16),
            _buildSummaryRow(
              'Total Dépenses',
              expenses,
              hasError ? Colors.red : Colors.orange.shade800,
              isLoading,
            ),
          ],
        ),
      ),
    );
  }

  // Widget helper pour une ligne du résumé
  Widget _buildSummaryRow(String label, String value, Color valueColor, bool isLoading) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        isLoading
            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(
                value,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: valueColor),
              ),
      ],
    );
  }

  // --- Widgets pour les items de la liste de transactions ---

  // Item pour une commande
  Widget _buildOrderTransactionItem(OrderTransaction tx) {
    bool isExpedition = tx.amount < 0;
    String title = isExpedition ? 'Expédition #${tx.orderId}' : 'Commande #${tx.orderId}';
    IconData icon = isExpedition ? Icons.local_shipping_outlined : Icons.inventory_2_outlined;
    String statusText;
    Color statusColor;

    // Logique du badge de statut reprise de ridercash.js
    if (tx.remittanceStatus == 'confirmed') {
      statusText = 'Confirmé';
      statusColor = Colors.green;
    } else { // pending
      statusText = isExpedition ? 'Frais à confirmer' : 'Cash à verser';
      statusColor = Colors.orange;
    }

    return ListTile(
      leading: Icon(icon, color: AppTheme.secondaryColor, size: 30),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tx.shopName != null) Text('Marchand: ${tx.shopName}', style: const TextStyle(fontSize: 12)),
          if (tx.itemsList != null) Text('Articles: ${tx.itemsList}', style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
          if (tx.deliveryLocation != null) Text('Lieu: ${tx.deliveryLocation}', style: const TextStyle(fontSize: 12)),
        ],
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            formatTransactionAmount(tx.amount, tx.type), // Utilise la fonction globale
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: getTransactionAmountColor(tx.amount, tx.type)),
          ),
          const SizedBox(height: 4),
           Row( // Pour afficher le statut
             mainAxisSize: MainAxisSize.min,
             children: [
               Icon(Icons.circle, size: 8, color: statusColor),
               const SizedBox(width: 4),
               Text(statusText, style: TextStyle(fontSize: 11, color: statusColor)),
             ],
           ),
           // Affiche le montant confirmé seulement si différent du montant total et > 0
           if (tx.remittanceStatus == 'confirmed' && tx.confirmedAmount > 0 && tx.amount.abs() != tx.confirmedAmount)
              Text(
                '(${currencyFormatter.format(tx.confirmedAmount)})',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),

        ],
      ),
      isThreeLine: true,
    );
  }

  // Item pour une dépense
  Widget _buildExpenseTransactionItem(ExpenseTransaction tx) {
    return ListTile(
      leading: Icon(Icons.receipt_long_outlined, color: Colors.orange.shade800, size: 30),
      title: const Text('Dépense', style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: tx.comment != null && tx.comment!.isNotEmpty ? Text(tx.comment!, style: const TextStyle(fontSize: 12)) : null,
      trailing: Column(
         crossAxisAlignment: CrossAxisAlignment.end,
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
             Text(
              formatTransactionAmount(tx.amount, tx.type),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: getTransactionAmountColor(tx.amount, tx.type)),
            ),
             _buildStatusBadge(tx.status), // Utilise le helper pour le statut générique
         ],
      ),
       isThreeLine: tx.comment != null && tx.comment!.isNotEmpty,
    );
  }

  // Item pour un manquant
  Widget _buildShortfallTransactionItem(ShortfallTransaction tx) {
    return ListTile(
      leading: Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 30),
      title: const Text('Manquant', style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: tx.comment != null && tx.comment!.isNotEmpty ? Text(tx.comment!, style: const TextStyle(fontSize: 12)) : null,
      trailing: Column(
         crossAxisAlignment: CrossAxisAlignment.end,
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
            Text(
              formatTransactionAmount(tx.amount, tx.type),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: getTransactionAmountColor(tx.amount, tx.type)),
            ),
             _buildStatusBadge(tx.status),
         ],
      ),
      isThreeLine: tx.comment != null && tx.comment!.isNotEmpty,
    );
  }

  // Helper pour afficher le badge de statut générique (pending, confirmed, paid, etc.)
   Widget _buildStatusBadge(String status) {
    String statusText;
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'pending':
        statusText = 'En attente';
        statusColor = Colors.orange;
        statusIcon = Icons.circle; // Simple point
        break;
      case 'confirmed': case 'paid': // Traite 'paid' comme 'confirmed'
        statusText = 'Réglé';
        statusColor = Colors.green;
         statusIcon = Icons.circle;
        break;
       case 'partially_paid':
        statusText = 'Partiel';
        statusColor = Colors.blue;
         statusIcon = Icons.circle;
        break;
      default:
        statusText = status;
        statusColor = Colors.grey;
         statusIcon = Icons.circle;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(statusIcon, size: 8, color: statusColor),
        const SizedBox(width: 4),
        Text(statusText, style: TextStyle(fontSize: 11, color: statusColor)),
      ],
    );
  }

} // Fin _RiderCashScreenState
// lib/models/rider_cash_details.dart

import 'package:intl/intl.dart';
import 'package:flutter/material.dart'; // Import pour Color et debugPrint
import '../utils/app_theme.dart';     // Import pour AppTheme

// Modèle pour le résumé
class CashSummary {
  final double amountExpected;
  final double amountConfirmed;
  final double totalExpenses;

  CashSummary({
    required this.amountExpected,
    required this.amountConfirmed,
    required this.totalExpenses,
  });

  factory CashSummary.fromJson(Map<String, dynamic> json) {
    return CashSummary(
      amountExpected: (json['amountExpected'] as num? ?? 0).toDouble(),
      amountConfirmed: (json['amountConfirmed'] as num? ?? 0).toDouble(),
      totalExpenses: (json['totalExpenses'] as num? ?? 0).toDouble(),
    );
  }
}

// Modèle de base pour une transaction
abstract class CashTransaction {
  final String type;
  final DateTime eventDate;
  final double amount;
  final String status;
  final int id; // Ajout d'un ID commun

  CashTransaction({
    required this.id,
    required this.type,
    required this.eventDate,
    required this.amount,
    required this.status,
  });

  // Méthode statique pour parser n'importe quelle transaction
  static CashTransaction fromJson(Map<String, dynamic> json) {
    String type = json['type'] as String;
    switch (type) {
      case 'order':
        return OrderTransaction.fromJson(json);
      case 'expense':
        return ExpenseTransaction.fromJson(json);
      case 'shortfall':
        return ShortfallTransaction.fromJson(json);
      default:
        // Remplacement de print par debugPrint
         debugPrint('Unknown transaction type encountered: $type');
         // Retourne une transaction factice ou null selon votre gestion d'erreur
         return UnknownTransaction.fromJson(json); // Exemple avec une classe UnknownTransaction
    }
  }
}

// Modèle pour une transaction de type Commande
class OrderTransaction extends CashTransaction {
  final int orderId;
  final String? shopName;
  final String? itemsList;
  final String? deliveryLocation;
  final String? customerName;
  final String? customerPhone;
  final String remittanceStatus; // Statut spécifique du versement (pending/confirmed)
  final double confirmedAmount; // Montant réellement confirmé

  // Utilisation de super parameters pour id, eventDate, amount, status
  OrderTransaction({
    required super.id, 
    required super.eventDate,
    required super.amount, 
    required super.status, 
    required this.orderId,
    this.shopName,
    this.itemsList,
    this.deliveryLocation,
    this.customerName,
    this.customerPhone,
    required this.remittanceStatus,
    required this.confirmedAmount,
  }) : super(type: 'order'); // 'type' est passé directement car il est fixe

  factory OrderTransaction.fromJson(Map<String, dynamic> json) {
    return OrderTransaction(
      id: json['id'] as int? ?? json['tracking_number'] as int? ?? 0, // Prend id ou tracking_number
      eventDate: DateTime.parse(json['event_date'] as String),
      amount: (json['article_amount'] as num? ?? 0).toDouble(), // article_amount ajusté
      status: json['status'] as String? ?? 'unknown', // Statut global de la commande
      orderId: json['id'] as int? ?? json['tracking_number'] as int? ?? 0,
      shopName: json['shop_name'] as String?,
      itemsList: json['items_list'] as String?,
      deliveryLocation: json['delivery_location'] as String?,
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String?,
      remittanceStatus: json['remittance_status'] as String? ?? 'pending',
      confirmedAmount: (json['confirmedAmount'] as num? ?? 0).toDouble(),
    );
  }
}

// Modèle pour une transaction de type Dépense
class ExpenseTransaction extends CashTransaction {
  final String? comment;

  // Utilisation de super parameters
  ExpenseTransaction({
    required super.id,
    required super.eventDate,
    required super.amount,
    required super.status,
    this.comment,
  }) : super(type: 'expense');

  factory ExpenseTransaction.fromJson(Map<String, dynamic> json) {
    return ExpenseTransaction(
      id: json['id'] as int? ?? 0,
      eventDate: DateTime.parse(json['event_date'] as String),
      amount: (json['amount'] as num? ?? 0).toDouble(),
      status: json['status'] as String? ?? 'unknown',
      comment: json['comment'] as String?,
    );
  }
}

// Modèle pour une transaction de type Manquant
class ShortfallTransaction extends CashTransaction {
  final String? comment;

  // Utilisation de super parameters
  ShortfallTransaction({
    required super.id,
    required super.eventDate,
    required super.amount,
    required super.status,
    this.comment,
  }) : super(type: 'shortfall');

  factory ShortfallTransaction.fromJson(Map<String, dynamic> json) {
    return ShortfallTransaction(
      id: json['id'] as int? ?? 0,
      eventDate: DateTime.parse(json['event_date'] as String),
      amount: (json['amount'] as num? ?? 0).toDouble(),
      status: json['status'] as String? ?? 'unknown',
      comment: json['comment'] as String?,
    );
  }
}

// Classe pour gérer les types de transactions inconnus (plus robuste)
class UnknownTransaction extends CashTransaction {
   final Map<String, dynamic> originalData;

   // Utilisation de super parameters
   UnknownTransaction({
    required super.id,
    required super.eventDate,
    required super.amount,
    required super.status,
    required this.originalData,
  }) : super(type: 'unknown');

   factory UnknownTransaction.fromJson(Map<String, dynamic> json) {
     return UnknownTransaction(
       id: json['id'] as int? ?? 0,
       eventDate: DateTime.tryParse(json['event_date'] as String? ?? '') ?? DateTime.now(),
       amount: (json['amount'] as num? ?? 0).toDouble(),
       status: json['status'] as String? ?? 'unknown',
       originalData: json,
     );
   }
}


// Modèle global pour la réponse de l'API
class RiderCashDetails {
  final CashSummary summary;
  final List<CashTransaction> transactions;

  RiderCashDetails({required this.summary, required this.transactions});

  // Le factory constructor est correct ici. Les erreurs précédentes venaient probablement d'ailleurs.
  factory RiderCashDetails.fromJson(Map<String, dynamic> json) {
    // Vérifie si les clés existent et sont du bon type avant de parser
    final summaryData = json['summary'] as Map<String, dynamic>? ?? {};
    final transactionsData = json['transactions'] as List<dynamic>? ?? [];

    return RiderCashDetails(
      summary: CashSummary.fromJson(summaryData),
      transactions: transactionsData
          .map((item) {
              try {
                return CashTransaction.fromJson(item as Map<String, dynamic>);
              } catch (e) {
                 // Remplacement de print par debugPrint
                 debugPrint("Erreur parsing transaction item: $e, Data: $item");
                 // Retourne un objet UnknownTransaction en cas d'erreur de parsing
                 return UnknownTransaction.fromJson(item as Map<String, dynamic>? ?? {});
              }
          })
          .toList(),
    );
  }
}

// --- Fonctions utilitaires de formatage ---
// Déplacées ici pour être accessibles par l'écran qui utilise ces modèles

final currencyFormatter = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);
final dateFormatter = DateFormat('dd/MM/yyyy', 'fr_FR');
final dateTimeFormatter = DateFormat('dd/MM HH:mm', 'fr_FR');

String formatTransactionAmount(double amount, String type) {
  bool isNegative = type == 'expense' || type == 'shortfall' || (type == 'order' && amount < 0); // Ordres d'expédition
  String formatted = currencyFormatter.format(amount.abs());
  return isNegative ? '- $formatted' : formatted; // Ajoute un espace pour l'alignement
}

Color getTransactionAmountColor(double amount, String type) {
   bool isNegative = type == 'expense' || type == 'shortfall' || (type == 'order' && amount < 0);
   if (type == 'order' && !isNegative) return AppTheme.primaryColor; // Corail pour encaissement commande
   if (type == 'expense' || (type == 'order' && isNegative)) return Colors.orange.shade800; // Orange pour dépenses/expéditions
   if (type == 'shortfall') return AppTheme.danger; // Rouge pour manquants
   return Colors.grey.shade700; // Couleur par défaut pour inconnu
}
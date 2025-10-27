// lib/models/order.dart

class OrderItem {
  final String itemName;
  final int quantity;
  final double amount; // Montant unitaire

  OrderItem({
    required this.itemName,
    required this.quantity,
    required this.amount,
  });

  // Factory constructor pour créer un OrderItem à partir d'un JSON/Map
  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      itemName: json['item_name'] as String? ?? 'N/A',
      quantity: (json['quantity'] as num? ?? 0).toInt(),
      amount: (json['amount'] as num? ?? 0).toDouble(),
    );
  }
}

class Order {
  final int id;
  final String shopName;
  final String? deliverymanName;
  final String? customerName;
  final String customerPhone;
  final String deliveryLocation;
  final double articleAmount;
  final double deliveryFee;
  final String status;
  final String paymentStatus;
  final DateTime createdAt;
  final double? amountReceived;
  final int unreadCount;
  final bool isUrgent;
  final String? itemsList; // Chaîne formatée pour l'affichage rapide (comme dans rider.model.js)
  final bool isPickedUp; // Basé sur picked_up_by_rider_at

  // Statuts à traiter en priorité pour l'écran Aujourd'hui (basé sur rider-common.js)
  static const List<String> unprocessedStatuses = [
    'pending', 
    'in_progress', 
    'ready_for_pickup', 
    'en_route', 
    'reported', 
    'return_declared'
  ];

  Order({
    required this.id,
    required this.shopName,
    this.deliverymanName,
    this.customerName,
    required this.customerPhone,
    required this.deliveryLocation,
    required this.articleAmount,
    required this.deliveryFee,
    required this.status,
    required this.paymentStatus,
    required this.createdAt,
    this.amountReceived,
    required this.unreadCount,
    required this.isUrgent,
    this.itemsList,
    required this.isPickedUp,
  });

  // Factory constructor pour créer un objet Order à partir du JSON de l'API /api/rider/orders
  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as int,
      shopName: json['shop_name'] as String? ?? 'N/A',
      deliverymanName: json['deliveryman_name'] as String?,
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String,
      deliveryLocation: json['delivery_location'] as String,
      // Conversion des types numériques (API renvoie souvent des chaînes ou des doubles pour les Decimals)
      articleAmount: (json['article_amount'] as num? ?? 0).toDouble(),
      deliveryFee: (json['delivery_fee'] as num? ?? 0).toDouble(),
      
      status: json['status'] as String,
      paymentStatus: json['payment_status'] as String,
      
      // Conversion de la date
      createdAt: DateTime.parse(json['created_at'] as String),
      
      // Montant reçu (peut être null)
      amountReceived: (json['amount_received'] as num?)?.toDouble(),

      // Champs spécifiques à l'affichage Livreur
      unreadCount: (json['unread_count'] as num? ?? 0).toInt(), // Vient de la sous-requête dans rider.model.js
      isUrgent: (json['is_urgent'] as int? ?? 0) == 1,
      itemsList: json['items_list'] as String?,
      isPickedUp: json['picked_up_by_rider_at'] != null, // picked_up_by_rider_at est un DateTime ou NULL
    );
  }
  
  // Utilitaire pour afficher le montant à encaisser (basé sur le total de l'article)
  double get amountToCollect => articleAmount;

  // Nouvelle méthode de comparaison pour le tri de l'écran "Aujourd'hui" (implémentation de la logique PWA)
  int compareToForToday(Order other) {
    final aIsUnprocessed = unprocessedStatuses.contains(status);
    final bIsUnprocessed = unprocessedStatuses.contains(other.status);

    // 1. Priorité aux statuts "en cours de traitement"
    if (aIsUnprocessed && !bIsUnprocessed) return -1;
    if (!aIsUnprocessed && bIsUnprocessed) return 1;

    if (aIsUnprocessed && bIsUnprocessed) {
      // 2. Priorité aux commandes 'ready_for_pickup' qui n'ont pas encore été récupérées
      final aIsReadyNotPickedUp = status == 'ready_for_pickup' && !isPickedUp;
      final bIsReadyNotPickedUp = other.status == 'ready_for_pickup' && !other.isPickedUp;

      if (aIsReadyNotPickedUp && !bIsReadyNotPickedUp) return -1;
      if (!aIsReadyNotPickedUp && bIsReadyNotPickedUp) return 1;

      // 3. Priorité aux commandes urgentes (true vient avant false)
      if (isUrgent != other.isUrgent) return isUrgent ? -1 : 1;
    }

    // 4. Par défaut, trier par date de création (du plus ancien au plus récent)
    return createdAt.compareTo(other.createdAt);
  }
}
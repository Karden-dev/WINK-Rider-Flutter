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
      // Les données brutes de la liste d'items sont formatées en chaîne dans rider.model.js (items_list)
      // Pour l'instant, nous allons nous concentrer sur le champ items_list comme un tout pour simplifier la migration
      // et nous reverrons la structure si nous devons interagir avec des OrderItem individuels.
      // Dans le cas de l'API /rider/orders, items_list est une chaîne comme "Article 1 (x1), Article 2 (x2)"
      // Cependant, le modèle Order devrait avoir une liste d'objets OrderItem si on s'aligne sur order.model.js
      // Pour l'affichage Livreur (rider.model.js), nous n'avons que items_list:
      // Nous allons donc utiliser une approche simplifiée, mais en préparant le terrain pour la liste d'objets si nécessaire.
      
      // Pour le moment, nous allons utiliser une structure pour les items qui sera ensuite ignorée par le Order.fromJson
      // qui utilise le champ agrégé `items_list` de rider.model.js.
      // Si on veut une vraie liste d'items, l'API /rider/orders doit être modifiée pour renvoyer le tableau d'items.
      
      // Pour rester fidèle aux champs du backend `order_items`
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
}
// lib/models/sync_request.dart

class SyncRequest {
  int? id; // L'ID de la base de données (clé primaire)
  final String url;
  final String method; // POST, PUT, DELETE
  final String payload; // Corps de la requête encodé en JSON string
  final String token; // Token JWT au moment de la création

  SyncRequest({
    this.id,
    required this.url,
    required this.method,
    required this.payload,
    required this.token,
  });

  // Convertit un Map (ligne de DB) en objet SyncRequest
  factory SyncRequest.fromMap(Map<String, dynamic> map) {
    return SyncRequest(
      id: map['id'] as int?,
      url: map['url'] as String,
      method: map['method'] as String,
      payload: map['payload'] as String,
      token: map['token'] as String,
    );
  }

  // Convertit l'objet SyncRequest en Map (pour l'insertion en DB)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'method': method,
      'payload': payload,
      'token': token,
    };
  }
}
// lib/services/sync_service.dart

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
// Correction des imports SQFlite et Path
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p; // Utilisation d'un alias 'p' pour éviter les conflits
// Correction de l'import Connectivity
import 'package:connectivity_plus/connectivity_plus.dart'; 

import '../models/sync_request.dart';
// import 'notification_service.dart'; // TODO: Importer si vous voulez une notification après sync

class SyncService extends ChangeNotifier {
  static const String _dbName = 'wink_sync_db.db';
  static const String _tableName = 'sync_requests';
  Database? _database;
  final Dio _dio;
  
  SyncService(this._dio);

  // --- Initialisation de la Base de Données ---

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    // Utilisation des fonctions de sqflite
    final dbPath = await getDatabasesPath(); 
    // Utilisation de l'alias p pour join
    final path = p.join(dbPath, _dbName); 
    
    // Utilisation de la fonction openDatabase de sqflite
    return await openDatabase( 
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            url TEXT,
            method TEXT,
            payload TEXT,
            token TEXT
          )
        ''');
      },
    );
  }

  // --- Opérations CRUD (Similaire à db-helper.js) ---

  /// Ajoute une requête à la file d'attente
  Future<void> addRequest(SyncRequest request) async {
    final db = await database;
    // Utilisation de ConflictAlgorithm de sqflite
    await db.insert(_tableName, request.toMap(), conflictAlgorithm: ConflictAlgorithm.replace); 
    debugPrint('Sync: Requête ajoutée à la file: ${request.url}');
  }

  /// Récupère toutes les requêtes en attente
  Future<List<SyncRequest>> getAllRequests() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(_tableName);
    return List.generate(maps.length, (i) => SyncRequest.fromMap(maps[i]));
  }

  /// Supprime une requête par ID
  Future<void> deleteRequest(int id) async {
    final db = await database;
    await db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }

  // --- Logique de Synchronisation ---
  
  void initializeConnectivityListener() {
    // Utilisation de Connectivity de connectivity_plus
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) { 
      // Utilisation de ConnectivityResult de connectivity_plus
      if (result != ConnectivityResult.none) { 
        debugPrint('Sync: Connexion rétablie. Tentative de synchronisation...');
        _replayFailedRequests();
      }
    });
    // Utilisation de Connectivity de connectivity_plus
    Connectivity().checkConnectivity().then((result) { 
      // Utilisation de ConnectivityResult de connectivity_plus
      if (result != ConnectivityResult.none) { 
        _replayFailedRequests();
      }
    });
  }

  /// Rejoue toutes les requêtes échouées stockées.
  Future<void> _replayFailedRequests() async {
    final requests = await getAllRequests();
    if (requests.isEmpty) {
      debugPrint('Sync: Aucune requête en attente.');
      return;
    }

    debugPrint('Sync: Début du rejeu de ${requests.length} requêtes...');
    int successCount = 0;

    for (final request in requests) {
      bool isSuccessful = await _replaySingleRequest(request);
      if (isSuccessful) {
        successCount++;
        if (request.id != null) { // Vérifier que l'ID n'est pas null
          await deleteRequest(request.id!);
        } else {
           debugPrint('Sync: Avertissement - Requête sans ID traitée : ${request.url}');
        }
      }
    }

    if (successCount > 0) {
      debugPrint('Sync: $successCount requête(s) rejouée(s) avec succès.');
      // TODO: Afficher une notification push locale de succès via NotificationService
    }
  }

  Future<bool> _replaySingleRequest(SyncRequest request) async {
    try {
      final headers = Options(headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${request.token}',
      });

      final response = await _dio.request(
        request.url,
        data: request.payload,
        options: headers.copyWith(method: request.method),
      );

      // Si la réponse est 2xx
      if (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300) {
        debugPrint('Sync: Requête réussie: ${request.url}');
        return true;
      }
      
      return false;
    } on DioException catch (e) {
      debugPrint('Sync: Échec du rejeu ${request.url}: ${e.response?.statusCode}');
      
      // Si c'est une erreur client (4xx) autre que 401/403, on la supprime
      if (e.response?.statusCode != null && 
          e.response!.statusCode! >= 400 && 
          e.response!.statusCode! < 500 && 
          e.response!.statusCode! != 401 && 
          e.response!.statusCode! != 403) {
         debugPrint('Sync: Supprimé car erreur client irrécupérable.');
         if (request.id != null) {
            await deleteRequest(request.id!);
         }
         return true; // Considéré comme "traité"
      }

      // Si 401/403 ou erreur serveur/réseau, on la garde pour plus tard
      return false;
    } catch (e) {
      // Erreur inattendue (e.g., parsing)
      debugPrint('Sync: Erreur inattendue: $e');
      return false;
    }
  }
  
  @override
  void dispose() {
    _database?.close();
    super.dispose();
  }
}
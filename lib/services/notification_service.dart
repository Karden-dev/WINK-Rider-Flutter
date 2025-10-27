// lib/services/notification_service.dart

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Initialisation du plugin
  Future<void> initialize() async {
    // Configuration Android: Utilisation d'une icône dans `android/app/src/main/res/drawable/app_icon.png`
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher'); 

    // Configuration iOS (ajuster si vous implémentez les permissions)
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      // Gérer le clic sur la notification si l'app est lancée/ouverte
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // TODO: Gérer la navigation basée sur le payload (ex: ouvrir ChatScreen pour un message)
        debugPrint('Notification payload: ${response.payload}');
      },
    );
    
    // Demander la permission pour iOS / Android 13+
    await _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();

    await _notificationsPlugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  // Afficher une notification
  Future<void> showNotification(int id, String title, String body, {String? payload}) async {
    // Paramètres Android (avec canal pour le son/vibration)
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'wink_rider_channel_id', // Id unique du canal
      'Notifications Livreur WINK', // Nom du canal
      channelDescription: 'Notifications pour les commandes assignées, messages et urgence.',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      // TODO: Configurer un son personnalisé si le fichier est ajouté dans les assets Android
      // sound: RawResourceAndroidNotificationSound('notification_sound'), 
    );

    const NotificationDetails platformChannelDetails =
        NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      id,
      title,
      body,
      platformChannelDetails,
      payload: payload,
    );
  }
}
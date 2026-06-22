import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Manejador en segundo plano para notificaciones
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Manejando mensaje en segundo plano: ${message.messageId}');
}

class PushNotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Inicializa el servicio, pide permisos y obtiene el token del dispositivo
  static Future<void> init() async {
    // 0. Inicializar notificaciones locales
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // Para iOS
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Usuario tocó la notificación local: ${response.payload}');
      },
    );

    // En Android 13+ requerimos pedir permiso para la app explícitamente desde LocalNotifications
    if (Platform.isAndroid) {
      await _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    // 1. Pedir permisos en iOS/Android a Firebase
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('Usuario otorgó permisos para notificaciones push');
    } else {
      debugPrint('Usuario declinó o no respondió al permiso de push');
      return; // Si no hay permisos, no podemos hacer mucho más
    }

    // 2. Configurar el handler si la app está en background
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Opcional para asegurar de que se vean y suenen en heads-up
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 3. Manejar mensajes cuando la aplicación está en primer plano
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Recibida notificación en Foreground: ${message.notification?.title}');
      
      // Mostrar la notificación localmente como un popup ("Heads-up")
      if (message.notification != null) {
        _showLocalNotification(message);
      }
    });

    // 4. Obtener y guardar el FCM token en Firestore
    await saveDeviceToken();

    // 5. Escuchar si el token cambia (por cuestiones internas de Firebase)
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      _safelySaveTokenToFirestore(newToken);
    });
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'high_importance_channel', // id del canal
      'Notificaciones Importantes', // nombre
      channelDescription: 'Este canal se usa para notificaciones importantes.',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _localNotificationsPlugin.show(
      id: message.notification.hashCode,
      title: message.notification?.title ?? 'Nueva notificación',
      body: message.notification?.body,
      notificationDetails: platformChannelSpecifics,
      payload: message.data['type'],
    );
  }

  /// Recupera el FCM Token actual del dispositivo y lo asocia al usuario logueado en Firestore
  static Future<void> saveDeviceToken() async {
    try {
      String? token;
      
      // En iOS puede ser útil esperar a que esté listo el APNS token antes de buscar el de FCM
      if (Platform.isIOS) {
        String? apnsToken = await _firebaseMessaging.getAPNSToken();
        if (apnsToken != null) {
          token = await _firebaseMessaging.getToken();
        } else {
          // Si el APNs tarda en estar listo, igual tratamos de conseguir el FCM Token
          await Future.delayed(const Duration(seconds: 3));
          token = await _firebaseMessaging.getToken();
        }
      } else {
        token = await _firebaseMessaging.getToken();
      }

      if (token != null) {
        debugPrint('FCM Token obtenido: $token');
        await _safelySaveTokenToFirestore(token);
      }
    } catch (e) {
      debugPrint('Error al obtener FCM Token: $e');
    }
  }

  /// Función interna para guardar en Firestore si hay usuario logueado
  static Future<void> _safelySaveTokenToFirestore(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {'fcmToken': token},
        SetOptions(merge: true),
      );
      debugPrint('FCM Token guardado exitosamente en Firestore para el usuario ${user.uid}');
    }
  }
}

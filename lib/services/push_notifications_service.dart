import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PushNotificationsService {
  static FirebaseMessaging messaging = FirebaseMessaging.instance;

  // 1. Inicializar y pedir permisos
  static Future<void> initializeApp() async {
    // Pedir permiso al usuario (Android 13+ y iOS lo necesitan)
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print('Estado de permisos: ${settings.authorizationStatus}');

    // Escuchar notificaciones en primer plano
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('🔔 Notificación recibida: ${message.notification?.title}');
    });
  }

  // 2. Enviar el Token a tu base de datos en Render
  static Future<void> syncTokenWithBackend(String userEmail) async {
    try {
      String? token = await messaging.getToken();

      if (token != null) {
        print("🚀 Token de Firebase generado: $token");
        
        // REEMPLAZA ESTA URL con la tuya real de Render
        final url = Uri.parse('https://tu-app-en-render.onrender.com/api/users/update-token');
        
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': userEmail,
            'fcmToken': token,
          }),
        );

        if (response.statusCode == 200) {
          print("✅ Token sincronizado exitosamente con la DB en Render");
        } else {
          print("⚠️ Error del servidor: ${response.body}");
        }
      }
    } catch (e) {
      print("❌ Error de red al sincronizar token: $e");
    }
  }
}
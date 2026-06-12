import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'utils/globals.dart';
import 'screens/home_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/marketplace_panel.dart';
import 'package:app_importaciones/services/push_notifications_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyD-5h6mt99nb61is3i45l8e28ncfvn3o129",
          authDomain: "aling-app.firebaseapp.com",
          projectId: "aling-app",
          storageBucket: "aling-app.appspot.com",
          messagingSenderId: "687685478470",
          appId: "1:687685478470:web:13076f7f384a3c19e28ncf",
        ),
      );
    } else {
      await Firebase.initializeApp();
    }
    await PushNotificationsService.initializeApp();
  } catch (e) {
    debugPrint("Error en inicialización: $e");
  }

  runApp(const AlingApp());
}

class AlingApp extends StatelessWidget {
  const AlingApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepOrange,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  void changeTab(int index) => setState(() => _selectedIndex = index);

  @override
  void initState() {
    super.initState();
    _checkPersistedSession();
  }

  _checkPersistedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString('userEmail') != null) {
        final user = await googleSignIn.signInSilently();
        userNotifier.value = user;
      }
    } catch (e) {
      debugPrint("Sesión: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GoogleSignInAccount?>(
      valueListenable: userNotifier,
      builder: (context, user, _) {
        final List<Widget> screens = [
          const HomeScreen(),
          const CartScreen(),
          user == null ? const LoginRequiredScreen() : const MarketplacePanel(),
          const ProfileScreen(),
        ];

        final List<_AsideItem> items = [
          _AsideItem(icon: Icons.storefront_outlined, activeIcon: Icons.storefront, label: 'Tienda'),
          _AsideItem(icon: Icons.shopping_cart_outlined, activeIcon: Icons.shopping_cart, label: 'Carrito'),
          _AsideItem(icon: Icons.add_circle_outline, activeIcon: Icons.add_circle, label: 'Vender'),
          _AsideItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Perfil'),
        ];

        return Scaffold(
          body: Row(
            children: [
              // Aside fijo izquierdo
              Container(
                width: 200,
                color: const Color(0xFFD10000),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                      color: const Color(0xFFB71C1C),
                      child: const Text(
                        'NovaMarket',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Items de navegación
                    ...List.generate(items.length, (i) {
                      final selected = _selectedIndex == i;
                      return InkWell(
                        onTap: () => changeTab(i),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          color: selected ? const Color(0xFF8B0000) : Colors.transparent,
                          child: Row(
                            children: [
                              Icon(
                                selected ? items[i].activeIcon : items[i].icon,
                                color: Colors.white,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                items[i].label,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              // Contenido principal
              Expanded(child: screens[_selectedIndex]),
            ],
          ),
        );
      },
    );
  }
}

class _AsideItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _AsideItem({required this.icon, required this.activeIcon, required this.label});
}
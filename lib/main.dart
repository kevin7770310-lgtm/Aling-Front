import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'screens/address_screen.dart';
import 'package:app_importaciones/services/push_notifications_service.dart';

// --- ESTADO GLOBAL ---
final ValueNotifier<List<dynamic>> cartNotifier = ValueNotifier([]);
final ValueNotifier<GoogleSignInAccount?> userNotifier = ValueNotifier(null);

final GoogleSignIn _googleSignIn = GoogleSignIn(
  clientId: kIsWeb
      ? "687685478470-5h6mt99nb61is3i45l8e28ncfvn3o129.apps.googleusercontent.com"
      : null,
  signInOption: SignInOption.standard,
  scopes: ['email', 'https://www.googleapis.com/auth/userinfo.profile'],
);

class PushNotificationsService {
  static FirebaseMessaging messaging = FirebaseMessaging.instance;
  static String? token;

  static Future<void> initializeApp() async {
    // 1. Solicitar permisos (Esencial para iOS y Android 13+)
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('🔔 Permisos de notificaciones concedidos');

      // 2. Obtener el Token de Firebase (FCM Token)
      // Este es el código que identifica este celular en tu base de datos
      token = await messaging.getToken();

      debugPrint('================ FCM TOKEN ================');
      debugPrint(token ?? 'No se pudo obtener el token');
      debugPrint('===========================================');

      // TIP: Aquí es donde enviarías el token a tu backend de Node.js
      // Ejemplo: _sendTokenToBackend(token);
    } else {
      debugPrint('🚫 Permisos de notificaciones denegados');
    }

    // 3. Configurar manejadores de mensajes
    FirebaseMessaging.onMessage.listen(_onMessageHandler);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenApp);

    // Manejador para cuando la app está en segundo plano/cerrada
    FirebaseMessaging.onBackgroundMessage(_backgroundHandler);
  }

  // Se ejecuta cuando la app está abierta y llega un mensaje
  static Future<void> _onMessageHandler(RemoteMessage message) async {
    debugPrint('Mensaje en primer plano: ${message.notification?.title}');
  }

  // Se ejecuta cuando el usuario hace clic en la notificación
  static Future<void> _onMessageOpenApp(RemoteMessage message) async {
    debugPrint('App abierta desde notificación: ${message.notification?.body}');
  }

  // Manejador obligatorio para mensajes en segundo plano (debe ser estático)
  static Future<void> _backgroundHandler(RemoteMessage message) async {
    debugPrint('Mensaje en background: ${message.messageId}');
  }
}

void main() async {
  // 1. Asegurar que los canales de comunicación con el sistema nativo estén listos
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 2. Inicializar Firebase según la plataforma
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
      // En móvil, Firebase busca automáticamente el google-services.json
      await Firebase.initializeApp();
    }

    // 3. Inicializar servicios dependientes
    await PushNotificationsService.initializeApp();
  } catch (e) {
    // Registrar el error pero decidir si la app debe continuar
    debugPrint("Error en inicialización: $e");
    // Opcional: podrías mostrar una pantalla de error personalizada aquí
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
        final user = await _googleSignIn.signInSilently();
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

        return Scaffold(
          body: IndexedStack(index: _selectedIndex, children: screens),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
            ),
            child: NavigationBar(
              elevation: 0,
              backgroundColor: Colors.white,
              selectedIndex: _selectedIndex,
              onDestinationSelected: changeTab,
              indicatorColor: Colors.deepOrange.withOpacity(0.2),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.storefront_outlined),
                  selectedIcon: Icon(Icons.storefront),
                  label: 'Tienda',
                ),
                NavigationDestination(
                  icon: Icon(Icons.shopping_cart_outlined),
                  selectedIcon: Icon(Icons.shopping_cart),
                  label: 'Carrito',
                ),
                NavigationDestination(
                  icon: Icon(Icons.add_circle_outline),
                  selectedIcon: Icon(Icons.add_circle),
                  label: 'Vender',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Perfil',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// --- TIENDA (HOME) CON CARRUSEL Y ESQUELETOS ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List allProducts = [];
  List filteredProducts = [];
  final List<String> categories = [
    'Todos',
    'Víveres',
    'Tecnología',
    'Hogar',
    'Moda',
    'Otros',
  ];
  String selectedCategory = 'Todos';
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final res = await http
          .get(Uri.parse('https://aling-backend.onrender.com/api/products'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        if (mounted) {
          setState(() {
            allProducts = json.decode(res.body);
            _applyFilter();
            loading = false;
          });
        }
      } else {
        throw "Server Error";
      }
    } catch (e) {
      if (mounted)
        setState(() {
          error = "Conexión lenta con Aling. Reintenta.";
          loading = false;
        });
    }
  }

  void _applyFilter() {
    setState(() {
      if (selectedCategory == 'Todos') {
        filteredProducts = allProducts;
      } else {
        filteredProducts = allProducts.where((p) {
          String pCat = (p['category'] ?? 'Otros')
              .toString()
              .trim()
              .toLowerCase();
          String sCat = selectedCategory.trim().toLowerCase();
          return pCat == sCat;
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ALING MAYORISTA'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => showSearch(
              context: context,
              delegate: ProductSearchDelegate(allProducts),
            ),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: load),
        ],
      ),
      body: Column(
        children: [
          if (selectedCategory == 'Todos' && !loading) _buildPromoCarousel(),
          _buildCategoryChips(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildPromoCarousel() {
    return Container(
      height: 130,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: PageView(
        children: [
          _buildPromoItem(
            "Ofertas Aling",
            "Mayorista en Santo Domingo",
            Colors.deepOrange,
          ),
          _buildPromoItem(
            "Nuevos Ingresos",
            "Tecnología y más",
            Colors.black87,
          ),
        ],
      ),
    );
  }

  Widget _buildPromoItem(String t, String s, Color c) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(s, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 55,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: categories.length,
        itemBuilder: (ctx, i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ChoiceChip(
            label: Text(categories[i]),
            selected: selectedCategory == categories[i],
            selectedColor: Colors.deepOrange,
            labelStyle: TextStyle(
              color: selectedCategory == categories[i]
                  ? Colors.white
                  : Colors.black,
            ),
            onSelected: (v) {
              setState(() {
                selectedCategory = categories[i];
                _applyFilter();
              });
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (loading) return _buildSkeletonGrid();
    if (error != null)
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 50, color: Colors.grey),
            Text(error!),
            ElevatedButton(onPressed: load, child: const Text("Reintentar")),
          ],
        ),
      );
    if (filteredProducts.isEmpty)
      return const Center(child: Text("No hay productos aquí."));

    return RefreshIndicator(
      onRefresh: load,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.72,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
        ),
        itemCount: filteredProducts.length,
        itemBuilder: (ctx, i) => _ProductCard(product: filteredProducts[i]),
      ),
    );
  }

  Widget _buildSkeletonGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      itemCount: 4,
      itemBuilder: (ctx, i) => Container(
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(15),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final dynamic product;
  const _ProductCard({required this.product});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (c) => ProductDetailScreen(product: product),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                ),
                child: Image.network(
                  product['imageUrl'] ?? '',
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (_, __, ___) => const Icon(Icons.image),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '\$${product['factoryPrice']}',
                    style: const TextStyle(
                      color: Colors.deepOrange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- DETALLE PRODUCTO ---
class ProductDetailScreen extends StatelessWidget {
  final dynamic product;
  const ProductDetailScreen({super.key, required this.product});

  // 🚀 Función de WhatsApp mejorada
  void _whatsapp(BuildContext context) async {
    // Usamos el teléfono del producto o el tuyo por defecto
    String phone = product['sellerPhone'] ?? '593982822157';

    // Limpiamos el número de espacios o caracteres extraños por si acaso
    phone = phone.replaceAll(RegExp(r'[^0-9]'), '');

    String message =
        "¡Hola! Estoy interesado en este producto de Aling Mayorista:\n\n"
        "*Producto:* ${product['name']}\n"
        "*Precio:* \$${product['factoryPrice']}\n\n"
        "¿Está disponible?";

    final url = "https://wa.me/$phone?text=${Uri.encodeComponent(message)}";

    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        throw "No se pudo abrir la URL";
      }
    } catch (e) {
      // 🚀 Si falla, mostramos el aviso visual
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Hubo un problema al abrir WhatsApp. Verifica que esté instalado.",
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del Producto')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Image.network(
              product['imageUrl'] ?? '',
              height: 350,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 100),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name'] ?? '',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '\$${product['factoryPrice']}',
                    style: const TextStyle(
                      fontSize: 26,
                      color: Colors.deepOrange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Chip(
                    label: Text(product['category'] ?? 'Otros'),
                    backgroundColor: Colors.orange.shade50,
                  ),
                  const Divider(height: 30),
                  const Text(
                    'Descripción',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    product['description'] ?? 'Sin descripción.',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(20),
        color: Colors.white,
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: () {
                  cartNotifier.value = List.from(cartNotifier.value)
                    ..add(product);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text(' Agregado al carrito')),
                  );
                },
                child: const Text('AL CARRITO'),
              ),
            ),
            const SizedBox(width: 10),
            // 🚀 BOTÓN DE WHATSAPP
            FloatingActionButton(
              backgroundColor: const Color(0xFF25D366),
              onPressed: () => _whatsapp(context), // Pasamos el context aquí
              child: const Icon(Icons.chat, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

// --- CARRITO ---
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GoogleSignInAccount?>(
      valueListenable: userNotifier,
      builder: (context, user, _) {
        if (user == null) return const LoginRequiredScreen();
        return ValueListenableBuilder<List>(
          valueListenable: cartNotifier,
          builder: (ctx, list, _) {
            double total = 0;
            for (var item in list)
              total += double.tryParse(item['factoryPrice'].toString()) ?? 0;
            return Scaffold(
              appBar: AppBar(title: const Text('Mi Carrito')),
              body: list.isEmpty
                  ? const Center(child: Text("Tu carrito está vacío"))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: list.length,
                      itemBuilder: (ctx, i) => Card(
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              list[i]['imageUrl'],
                              width: 50,
                              fit: BoxFit.cover,
                            ),
                          ),
                          title: Text(list[i]['name']),
                          subtitle: Text('\$${list[i]['factoryPrice']}'),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: () => cartNotifier.value = List.from(
                              cartNotifier.value,
                            )..removeAt(i),
                          ),
                        ),
                      ),
                    ),
              bottomNavigationBar: list.isEmpty
                  ? null
                  : Container(
                      padding: const EdgeInsets.all(20),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 60),
                          backgroundColor: Colors.deepOrange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (c) =>
                                AddressScreen(total: total, email: user.email),
                          ),
                        ),
                        child: Text('PAGAR \$${total.toStringAsFixed(2)}'),
                      ),
                    ),
            );
          },
        );
      },
    );
  }
}

// --- PERFIL ---
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GoogleSignInAccount?>(
      valueListenable: userNotifier,
      builder: (context, user, _) {
        if (user == null) return _buildLogin(context);
        return Scaffold(
          appBar: AppBar(title: const Text('Mi Cuenta')),
          body: Column(
            children: [
              const SizedBox(height: 30),
              CircleAvatar(
                radius: 50,
                backgroundImage: user.photoUrl != null
                    ? NetworkImage(user.photoUrl!)
                    : null,
              ),
              const SizedBox(height: 15),
              Text(
                user.displayName ?? 'Kevin',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(user.email, style: const TextStyle(color: Colors.grey)),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(20),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar Sesión'),
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.clear();
                    await _googleSignIn.signOut();
                    userNotifier.value = null;
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLogin(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.shopping_bag_outlined,
                size: 100,
                color: Colors.deepOrange,
              ),
              const SizedBox(height: 30),
              const Text(
                "Bienvenido a Aling",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 50),
              ElevatedButton.icon(
                icon: const Icon(Icons.login),
                label: const Text("CONTINUAR CON GOOGLE"),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 55),
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: () async {
                  try {
                    final u = await _googleSignIn.signIn();
                    if (u != null) {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('userEmail', u.email);
                      userNotifier.value = u;
                    }
                  } catch (e) {
                    debugPrint(e.toString());
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginRequiredScreen extends StatelessWidget {
  const LoginRequiredScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_circle_outlined,
              size: 100,
              color: Colors.deepOrange.shade100,
            ),
            const Text(
              "Acceso Requerido",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                final mainState = context
                    .findAncestorStateOfType<MainScreenState>();
                mainState?.changeTab(3);
              },
              child: const Text("IR AL LOGIN"),
            ),
          ],
        ),
      ),
    );
  }
}

// --- MARKETPLACE PANEL ---
class MarketplacePanel extends StatelessWidget {
  const MarketplacePanel({super.key});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mi Negocio'),
          bottom: const TabBar(
            labelColor: Colors.deepOrange,
            tabs: [
              Tab(text: 'Publicar'),
              Tab(text: 'Mis Productos'),
            ],
          ),
        ),
        body: const TabBarView(children: [VenderAddTab(), VenderManageTab()]),
      ),
    );
  }
}

class VenderAddTab extends StatefulWidget {
  const VenderAddTab({super.key});
  @override
  State<VenderAddTab> createState() => _VenderAddTabState();
}

class _VenderAddTabState extends State<VenderAddTab> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _selectedCategory = 'Otros';
  XFile? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isSaving = false;

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _imageFile = image);
  }

  Future<void> _addProduct() async {
    if (_nameCtrl.text.isEmpty || _priceCtrl.text.isEmpty || _imageFile == null)
      return;
    setState(() => _isSaving = true);
    try {
      var req = http.MultipartRequest(
        'POST',
        Uri.parse('https://aling-backend.onrender.com/api/products'),
      );
      req.fields['name'] = _nameCtrl.text;
      req.fields['factoryPrice'] =
          double.tryParse(_priceCtrl.text)?.toStringAsFixed(2) ?? "0.00";
      req.fields['description'] = _descCtrl.text;
      req.fields['category'] = _selectedCategory;
      req.fields['sellerEmail'] = userNotifier.value?.email ?? '';
      if (kIsWeb) {
        req.files.add(
          http.MultipartFile.fromBytes(
            'image',
            await _imageFile!.readAsBytes(),
            filename: _imageFile!.name,
          ),
        );
      } else {
        req.files.add(
          await http.MultipartFile.fromPath('image', _imageFile!.path),
        );
      }
      await req.send();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Publicado correctamente')),
      );
      _nameCtrl.clear();
      _priceCtrl.clear();
      _descCtrl.clear();
      setState(() => _imageFile = null);
    } catch (e) {
      debugPrint(e.toString());
    }
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.deepOrange.withOpacity(0.3)),
              ),
              child: _imageFile == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo,
                          size: 40,
                          color: Colors.deepOrange,
                        ),
                        Text("Añadir Foto"),
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: kIsWeb
                          ? Image.network(_imageFile!.path, fit: BoxFit.cover)
                          : Image.file(
                              File(_imageFile!.path),
                              fit: BoxFit.cover,
                            ),
                    ),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _priceCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Precio \$',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 15),
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            decoration: const InputDecoration(
              labelText: 'Categoría',
              border: OutlineInputBorder(),
            ),
            items: [
              'Víveres',
              'Tecnología',
              'Hogar',
              'Moda',
              'Otros',
            ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (val) => setState(() => _selectedCategory = val!),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _descCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Descripción',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 25),
          _isSaving
              ? const CircularProgressIndicator()
              : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 55),
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: _addProduct,
                  child: const Text('PUBLICAR PRODUCTO'),
                ),
        ],
      ),
    );
  }
}

class VenderManageTab extends StatefulWidget {
  const VenderManageTab({super.key});
  @override
  State<VenderManageTab> createState() => _VenderManageTabState();
}

class _VenderManageTabState extends State<VenderManageTab> {
  List products = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (!mounted) return;
    try {
      final res = await http.get(
        Uri.parse('https://aling-backend.onrender.com/api/products'),
      );
      if (res.statusCode == 200) {
        List all = json.decode(res.body);
        if (mounted)
          setState(() {
            products = all
                .where((p) => p['sellerEmail'] == userNotifier.value?.email)
                .toList();
            loading = false;
          });
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  // 🚀 DIÁLOGO DE EDICIÓN CORREGIDO
  void _editProduct(dynamic p) {
    final nameCtrl = TextEditingController(text: p['name']);
    final priceCtrl = TextEditingController(text: p['factoryPrice'].toString());
    final descCtrl = TextEditingController(text: p['description'] ?? '');
    String localCategory = p['category'] ?? 'Otros'; // Valor inicial

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        // IMPORTANTE: StatefulBuilder permite que el Dropdown cambie visualmente
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text("Editar Producto"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Precio'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: localCategory,
                  items: ['Víveres', 'Tecnología', 'Hogar', 'Moda', 'Otros']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (val) => setDialogState(
                    () => localCategory = val!,
                  ), // Actualiza la variable local
                  decoration: const InputDecoration(
                    labelText: 'Categoría',
                    border: OutlineInputBorder(),
                  ),
                ),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final res = await http.put(
                  Uri.parse(
                    'https://aling-backend.onrender.com/api/products/${p['id']}',
                  ),
                  headers: {'Content-Type': 'application/json'},
                  body: json.encode({
                    'name': nameCtrl.text,
                    'factoryPrice': priceCtrl.text,
                    'description': descCtrl.text,
                    'category': localCategory, // 🚀 AHORA SÍ SE ENVÍA EL CAMBIO
                  }),
                );
                if (res.statusCode == 200) {
                  Navigator.pop(ctx);
                  load();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("✅ Actualizado")),
                  );
                }
              },
              child: const Text("Guardar"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return products.isEmpty
        ? const Center(child: Text("Sin publicaciones"))
        : ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: products.length,
            itemBuilder: (ctx, i) => Card(
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Image.network(
                    products[i]['imageUrl'],
                    width: 40,
                    fit: BoxFit.cover,
                  ),
                ),
                title: Text(products[i]['name']),
                subtitle: Text(
                  "\$${products[i]['factoryPrice']} • ${products[i]['category'] ?? 'Otros'}",
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _editProduct(products[i]),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        final res = await http.delete(
                          Uri.parse(
                            'https://aling-backend.onrender.com/api/products/${products[i]['id']}',
                          ),
                        );

                        // Solo recargamos la lista si la eliminación fue exitosa
                        if (res.statusCode == 200) {
                          load();
                        } else {
                          // Opcional: mostrar un aviso si algo salió mal
                          print("Error al borrar: ${res.statusCode}");
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
  }
}

class ProductSearchDelegate extends SearchDelegate {
  final List<dynamic> products;
  ProductSearchDelegate(this.products);
  @override
  String get searchFieldLabel => "Buscar en Aling...";
  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];
  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );
  @override
  Widget buildResults(BuildContext context) => _buildList();
  @override
  Widget buildSuggestions(BuildContext context) => _buildList();
  Widget _buildList() {
    final results = products
        .where(
          (p) =>
              p['name'].toString().toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    if (results.isEmpty) return const Center(child: Text("Sin resultados"));
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      itemCount: results.length,
      itemBuilder: (ctx, i) => _ProductCard(product: results[i]),
    );
  }
}

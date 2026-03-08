import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// --- ESTADO GLOBAL ---
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
final ValueNotifier<List<dynamic>> cartNotifier = ValueNotifier([]);
final ValueNotifier<GoogleSignInAccount?> userNotifier = ValueNotifier(null);
final ValueNotifier<bool> adminNotifier = ValueNotifier(false);

// 🔑 CLIENT ID Y SCOPES (Ajustado para resolver Error 403 Forbidden en Web)
final GoogleSignIn _googleSignIn = GoogleSignIn(
  clientId: kIsWeb ? "687685478470-5h6mt99nb61is3i45l8e28ncfvn3o129.apps.googleusercontent.com" : null,
  signInOption: SignInOption.standard,
  scopes: [
    'email',
    'https://www.googleapis.com/auth/userinfo.profile', // Permiso vital para leer perfil
  ],
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (kIsWeb) {
      // 🚀 Configuración extraída de tus capturas para estabilidad en Web
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyD-5h6mt99nb61is3i45l8e28ncfvn3o129", // Tu API Key
          authDomain: "aling-app.firebaseapp.com",
          projectId: "aling-app",
          storageBucket: "aling-app.appspot.com",
          messagingSenderId: "687685478470",
          appId: "1:687685478470:web:13076f7f384a3c19e28ncf", // Tu App ID de Web
        ),
      );
    } else {
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint("Error Firebase: $e");
  }
  runApp(const AlingApp());
}

class AlingApp extends StatelessWidget {
  const AlingApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.deepOrange,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            titleTextStyle: TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        home: const MainScreen(),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkPersistedSession();
  }

  _checkPersistedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('isAdmin') == true) {
        adminNotifier.value = true;
        return;
      } 
      
      if (prefs.getString('userEmail') != null) {
        final user = await _googleSignIn.signInSilently();
        userNotifier.value = user;
      }
    } catch (e) {
      debugPrint("Aviso de Google (Sesión persistida): $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      const HomeScreen(),
      const CartScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
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
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

// --- PANTALLA DE INICIO ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List products = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (!mounted) return;
    setState(() => loading = true);
    try {
      final res = await http
          .get(Uri.parse('https://aling-backend.onrender.com/api/products'))
          .timeout(const Duration(seconds: 40));
      if (res.statusCode == 200) {
        if (mounted) setState(() => products = json.decode(res.body));
      }
    } catch (e) {
      debugPrint(e.toString());
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aling Mayorista')),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.deepOrange),
            )
          : RefreshIndicator(
              onRefresh: load,
              color: Colors.deepOrange,
              child: GridView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.72,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemCount: products.length,
                itemBuilder: (ctx, i) => _ProductCard(product: products[i]),
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
    return ValueListenableBuilder<bool>(
      valueListenable: adminNotifier,
      builder: (context, isAdmin, _) =>
          ValueListenableBuilder<GoogleSignInAccount?>(
            valueListenable: userNotifier,
            builder: (context, user, _) {
              final bool isLoggedIn = user != null || isAdmin;
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (c) => ProductDetailScreen(
                      product: product,
                      isLoggedIn: isLoggedIn,
                    ),
                  ),
                ),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 3,
                  child: Column(
                    children: [
                      Expanded(
                        child: Hero(
                          tag: 'hero-${product['id']}',
                          child: Image.network(
                            product['imageUrl'] ?? '',
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 50),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
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
            },
          ),
    );
  }
}

class ProductDetailScreen extends StatelessWidget {
  final dynamic product;
  final bool isLoggedIn;
  const ProductDetailScreen({
    super.key,
    required this.product,
    required this.isLoggedIn,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalles')),
      body: Column(
        children: [
          Hero(
            tag: 'hero-${product['id']}',
            child: Image.network(
              product['imageUrl'] ?? '',
              height: 300,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox(
                height: 300,
                child: Center(child: Icon(Icons.image, size: 80, color: Colors.grey)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
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
                    fontSize: 22,
                    color: Colors.deepOrange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Distribución directa Aling Mayorista.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isLoggedIn
                          ? Colors.deepOrange
                          : Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      if (!isLoggedIn) {
                        try {
                          await _googleSignIn.signOut();
                          final u = await _googleSignIn.signIn();
                          if (u != null) {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString('userEmail', u.email);
                            userNotifier.value = u;
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('✅ Bienvenido ${u.displayName}')),
                              );
                            }
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('❌ Error al conectar con Google')),
                            );
                          }
                        }
                        return;
                      }

                      cartNotifier.value = List.from(cartNotifier.value)..add(product);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('✅ Agregado al carrito')),
                      );
                    },
                    child: Text(
                      isLoggedIn
                          ? 'Añadir al Carrito'
                          : 'Inicia sesión con Google para añadir',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- CARRITO ---
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: adminNotifier,
      builder: (context, isAdmin, _) =>
          ValueListenableBuilder<GoogleSignInAccount?>(
            valueListenable: userNotifier,
            builder: (context, user, _) {
              final bool isLoggedIn = user != null || isAdmin;

              if (!isLoggedIn) {
                return Scaffold(
                  appBar: AppBar(title: const Text('Mi Carrito')),
                  body: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.remove_shopping_cart_outlined, size: 80, color: Colors.grey),
                        SizedBox(height: 20),
                        Text('Tu carrito está bloqueado', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        Text('Debes iniciar sesión para comprar.', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                );
              }

              return ValueListenableBuilder<List>(
                valueListenable: cartNotifier,
                builder: (ctx, list, _) {
                  double total = 0;
                  for (var item in list) {
                    var p = item['factoryPrice'];
                    total += (p is String)
                        ? (double.tryParse(p) ?? 0)
                        : (p?.toDouble() ?? 0);
                  }
                  return Scaffold(
                    appBar: AppBar(title: const Text('Mi Carrito')),
                    body: list.isEmpty
                        ? const Center(child: Text('Carrito vacío'))
                        : Column(
                            children: [
                              Expanded(
                                child: ListView.builder(
                                  itemCount: list.length,
                                  itemBuilder: (ctx, i) => ListTile(
                                    leading: Image.network(
                                      list[i]['imageUrl'] ?? '',
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.image),
                                    ),
                                    title: Text(list[i]['name'] ?? ''),
                                    trailing: Text('\$${list[i]['factoryPrice']}'),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    Text(
                                      'Total: \$${total.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 10),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size(double.infinity, 50),
                                        backgroundColor: Colors.deepOrange,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () {
                                        String email = isAdmin ? 'admin@aling.com' : user!.email;
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (c) => CheckoutScreen(total: total, email: email),
                                          ),
                                        );
                                      },
                                      child: const Text('Proceder al Pago'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  );
                },
              );
            },
          ),
    );
  }
}

// --- PERFIL ---
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: adminNotifier,
      builder: (context, isAdmin, _) =>
          ValueListenableBuilder<GoogleSignInAccount?>(
            valueListenable: userNotifier,
            builder: (context, user, _) {
              if (isAdmin) return const AdminPanel();
              if (user != null) return _buildModernProfile(user);
              return _buildLogin(context);
            },
          ),
    );
  }

  Widget _buildModernProfile(GoogleSignInAccount user) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi Perfil'), elevation: 0),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              color: Colors.white,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.deepOrange.shade100,
                    backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                    child: user.photoUrl == null ? const Icon(Icons.person, size: 40, color: Colors.deepOrange) : null,
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName ?? 'Usuario',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text(user.email, style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            const ListTile(leading: Icon(Icons.shopping_bag_outlined), title: Text('Mis Pedidos'), trailing: Icon(Icons.chevron_right)),
            const ListTile(leading: Icon(Icons.location_on_outlined), title: Text('Mis Direcciones'), trailing: Icon(Icons.chevron_right)),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar Sesión'),
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.clear();
                    try { await _googleSignIn.signOut(); } catch (_) {}
                    userNotifier.value = null;
                    adminNotifier.value = false;
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogin(BuildContext context) {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final ValueNotifier<bool> obscureNotifier = ValueNotifier(true);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(35),
          child: Column(
            children: [
              const Icon(Icons.account_circle_outlined, size: 80, color: Colors.deepOrange),
              const SizedBox(height: 20),
              const Text('Iniciar Sesión', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Correo Admin', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),
              ValueListenableBuilder<bool>(
                valueListenable: obscureNotifier,
                builder: (context, obscure, _) {
                  return TextField(
                    controller: passCtrl,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                        onPressed: () => obscureNotifier.value = !obscureNotifier.value,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                  onPressed: () async {
                    if (emailCtrl.text.trim() == 'admin@aling.com' && passCtrl.text.trim() == 'admin123') {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('isAdmin', true);
                      adminNotifier.value = true;

                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const MainScreen()),
                          (route) => false,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('✅ Sesión iniciada como Admin')),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('❌ Credenciales incorrectas')),
                      );
                    }
                  },
                  child: const Text('Entrar como Admin'),
                ),
              ),
              const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text('O')),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.login),
                  label: const Text('Continuar con Google'),
                  onPressed: () async {
                    try {
                      await _googleSignIn.signOut();
                      final u = await _googleSignIn.signIn();
                      if (u != null) {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('userEmail', u.email);
                        userNotifier.value = u;
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('✅ Bienvenido ${u.displayName}')),
                          );
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('❌ Error al conectar con Google')),
                        );
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- PANEL ADMIN (MODIFICADO: AGREGAR, EDITAR, ELIMINAR) ---
class AdminPanel extends StatelessWidget {
  const AdminPanel({super.key});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Panel Administrativo'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                adminNotifier.value = false;
              },
            ),
          ],
          bottom: const TabBar(
            labelColor: Colors.deepOrange,
            indicatorColor: Colors.deepOrange,
            tabs: [
              Tab(icon: Icon(Icons.add_box), text: 'Subir Producto'),
              Tab(icon: Icon(Icons.edit), text: 'Gestionar'),
            ],
          ),
        ),
        body: const TabBarView(children: [AdminAddTab(), AdminManageTab()]),
      ),
    );
  }
}

class AdminAddTab extends StatefulWidget {
  const AdminAddTab({super.key});
  @override
  State<AdminAddTab> createState() => _AdminAddTabState();
}

class _AdminAddTabState extends State<AdminAddTab> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  bool _isSaving = false;

  Future<void> _addProduct() async {
    if (_nameCtrl.text.isEmpty || _priceCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Llena el nombre y el precio')),
      );
      return;
    }
    setState(() => _isSaving = true);
    
    try {
      final res = await http.post(
        Uri.parse('https://aling-backend.onrender.com/api/products'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': _nameCtrl.text,
          'factoryPrice': _priceCtrl.text,
          'imageUrl': _urlCtrl.text.isEmpty ? 'https://via.placeholder.com/300?text=Sin+Imagen' : _urlCtrl.text,
        }),
      );

      if (res.statusCode == 201) {
        _nameCtrl.clear();
        _priceCtrl.clear();
        _urlCtrl.clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Producto subido correctamente.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(25),
      child: Column(
        children: [
          TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nombre del Producto', border: OutlineInputBorder())),
          const SizedBox(height: 15),
          TextField(controller: _priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Precio USD', border: OutlineInputBorder())),
          const SizedBox(height: 15),
          TextField(controller: _urlCtrl, decoration: const InputDecoration(labelText: 'URL de la Imagen', border: OutlineInputBorder())),
          const SizedBox(height: 30),
          _isSaving
              ? const CircularProgressIndicator()
              : ElevatedButton(
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
                  onPressed: _addProduct,
                  child: const Text('Subir Producto'),
                ),
        ],
      ),
    );
  }
}

class AdminManageTab extends StatefulWidget {
  const AdminManageTab({super.key});
  @override
  State<AdminManageTab> createState() => _AdminManageTabState();
}

class _AdminManageTabState extends State<AdminManageTab> {
  List products = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (!mounted) return;
    setState(() => loading = true);
    try {
      final res = await http.get(Uri.parse('https://aling-backend.onrender.com/api/products'));
      if (res.statusCode == 200) {
        if (mounted) setState(() => products = json.decode(res.body));
      }
    } catch (e) {}
    if (mounted) setState(() => loading = false);
  }

  void _editProduct(dynamic p) {
    final nameCtrl = TextEditingController(text: p['name']);
    final priceCtrl = TextEditingController(text: p['factoryPrice'].toString());
    final urlCtrl = TextEditingController(text: p['imageUrl'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar Producto'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
              TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Precio')),
              TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'URL de Imagen')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await http.put(
                Uri.parse('https://aling-backend.onrender.com/api/products/${p['id']}'),
                headers: {'Content-Type': 'application/json'},
                body: json.encode({
                  'name': nameCtrl.text,
                  'factoryPrice': priceCtrl.text,
                  'imageUrl': urlCtrl.text.isEmpty ? p['imageUrl'] : urlCtrl.text,
                }),
              );
              load();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return ListView.builder(
      itemCount: products.length,
      itemBuilder: (ctx, i) {
        final p = products[i];
        return ListTile(
          leading: Image.network(p['imageUrl'] ?? '', width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image)),
          title: Text(p['name']),
          subtitle: Text('\$${p['factoryPrice']}'),
          trailing: IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _editProduct(p)),
        );
      },
    );
  }
}

// --- PANTALLA PAGO ---
class CheckoutScreen extends StatefulWidget {
  final double total;
  final String email;
  const CheckoutScreen({super.key, required this.total, required this.email});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pago Seguro')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
            const SizedBox(height: 20),
            Text('Total a Pagar: \$${widget.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            _isProcessing
                ? const CircularProgressIndicator(color: Colors.deepOrange)
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(minimumSize: const Size(200, 50), backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
                    onPressed: () async {
                      setState(() => _isProcessing = true);
                      try {
                        var res = await http.post(
                          Uri.parse('https://aling-backend.onrender.com/api/checkout'),
                          headers: {'Content-Type': 'application/json'},
                          body: json.encode({
                            'email': widget.email,
                            'totalAmount': widget.total.toStringAsFixed(2),
                          }),
                        ).timeout(const Duration(seconds: 15));

                        if (res.statusCode == 200) {
                          cartNotifier.value = [];
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Pedido exitoso.')));
                            Navigator.pop(context);
                          }
                        }
                      } catch (e) {}
                      if (mounted) setState(() => _isProcessing = false);
                    },
                    child: const Text('Finalizar Pedido'),
                  ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- VARIABLES GLOBALES ---
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
final ValueNotifier<List<dynamic>> cartNotifier = ValueNotifier([]); 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
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
            titleTextStyle: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
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
  GoogleSignInAccount? _currentUser;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkPersistedSession(); 
  }

  // RECUPERAR SESIÓN
  _checkPersistedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final bool? isAdminSaved = prefs.getBool('isAdmin');
    final String? userEmail = prefs.getString('userEmail');

    if (isAdminSaved == true) {
      setState(() => _isAdmin = true);
    } else if (userEmail != null) {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final user = await googleSignIn.signInSilently();
      setState(() => _currentUser = user);
    }
  }

  // CERRAR SESIÓN
  _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await GoogleSignIn().signOut();
    setState(() {
      _currentUser = null;
      _isAdmin = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      const HomeScreen(),
      const CartScreen(),
      ProfileScreen(
        user: _currentUser, 
        isAdmin: _isAdmin,
        onLogout: _logout,
        onLogin: (user, isAdmin) async {
          final prefs = await SharedPreferences.getInstance();
          if (isAdmin) {
            await prefs.setBool('isAdmin', true);
          } else if (user != null) {
            await prefs.setString('userEmail', user.email);
          }
          setState(() {
            _currentUser = user;
            _isAdmin = isAdmin;
          });
        },
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'Tienda'),
          NavigationDestination(icon: Icon(Icons.shopping_cart_outlined), selectedIcon: Icon(Icons.shopping_cart), label: 'Carrito'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}

// --- PANTALLA DE INICIO (TIENDA CON PULL-TO-REFRESH) ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List products = [];
  bool loading = true;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      final res = await http.get(Uri.parse('https://aling-backend.onrender.com/api/products'));
      if (res.statusCode == 200) setState(() => products = json.decode(res.body));
    } catch (e) { debugPrint(e.toString()); }
    if(mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aling Mayorista')),
      body: loading 
        ? const Center(child: CircularProgressIndicator()) 
        : RefreshIndicator( 
            onRefresh: load,
            color: Colors.deepOrange,
            child: GridView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, childAspectRatio: 0.72, mainAxisSpacing: 12, crossAxisSpacing: 12
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
    final mainState = context.findAncestorStateOfType<_MainScreenState>();
    final bool isLoggedIn = (mainState?._currentUser != null) || (mainState?._isAdmin == true);

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => ProductDetailScreen(product: product, isLoggedIn: isLoggedIn))),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 3,
        child: Column(children: [
          Expanded(
            child: Hero(
              tag: 'hero-${product['id']}', 
              child: Image.network(product['imageUrl'] ?? 'https://via.placeholder.com/150', width: double.infinity, fit: BoxFit.cover),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(children: [
              Text(product['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('\$${product['factoryPrice']}', style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
            ]),
          ),
        ]),
      ),
    );
  }
}

// --- DETALLE DE PRODUCTO (CON BLOQUEO DE BOTÓN) ---
class ProductDetailScreen extends StatelessWidget {
  final dynamic product;
  final bool isLoggedIn;
  const ProductDetailScreen({super.key, required this.product, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalles')),
      body: Column(children: [
        Hero(
          tag: 'hero-${product['id']}',
          child: Image.network(product['imageUrl'] ?? '', height: 300, width: double.infinity, fit: BoxFit.cover),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(product['name'] ?? '', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text('\$${product['factoryPrice']}', style: const TextStyle(fontSize: 22, color: Colors.deepOrange, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            const Text('Descripción', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Text('Distribución directa Aling Mayorista.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLoggedIn ? Colors.deepOrange : Colors.grey, 
                  foregroundColor: Colors.white
                ),
                onPressed: () {
                  if (!isLoggedIn) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Inicia sesión en Perfil para poder comprar')));
                    return; 
                  }
                  cartNotifier.value = List.from(cartNotifier.value)..add(product);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Agregado al carrito')));
                },
                child: Text(isLoggedIn ? 'Añadir al Carrito' : 'Inicia sesión para añadir'),
              ),
            )
          ]),
        )
      ]),
    );
  }
}

// --- CARRITO (CON PANTALLA DE BLOQUEO) ---
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mainState = context.findAncestorStateOfType<_MainScreenState>();
    final bool isLoggedIn = (mainState?._currentUser != null) || (mainState?._isAdmin == true);

    if (!isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mi Carrito')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.remove_shopping_cart_outlined, size: 80, color: Colors.grey),
              const SizedBox(height: 20),
              const Text('Tu carrito está bloqueado', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text('Debes iniciar sesión para comprar.', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
                onPressed: () {
                  mainState?.setState(() => mainState._selectedIndex = 2);
                },
                child: const Text('Ir a Iniciar Sesión')
              )
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
          total += (p is String) ? (double.tryParse(p) ?? 0) : (p?.toDouble() ?? 0);
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Mi Carrito')),
          body: list.isEmpty ? const Center(child: Text('Carrito vacío')) : Column(children: [
            Expanded(child: ListView.builder(itemCount: list.length, itemBuilder: (ctx, i) => ListTile(
              leading: Image.network(list[i]['imageUrl'] ?? '', width: 50, height: 50, fit: BoxFit.cover),
              title: Text(list[i]['name'] ?? ''),
              trailing: Text('\$${list[i]['factoryPrice']}'),
            ))),
            Padding(padding: const EdgeInsets.all(20), child: Column(children: [
              Text('Total: \$${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
                onPressed: () {
                  String email = mainState?._isAdmin == true ? 'admin@aling.com' : mainState!._currentUser!.email;
                  Navigator.push(context, MaterialPageRoute(builder: (c) => CheckoutScreen(total: total, email: email)));
                }, 
                child: const Text('Proceder al Pago')
              )
            ])),
          ]),
        );
      },
    );
  }
}

// --- PERFIL (LOGIN, ADMIN Y GESTIÓN DE PRODUCTOS) ---
class ProfileScreen extends StatefulWidget {
  final GoogleSignInAccount? user;
  final bool isAdmin;
  final VoidCallback onLogout; 
  final Function(GoogleSignInAccount?, bool) onLogin;
  const ProfileScreen({super.key, this.user, required this.isAdmin, required this.onLogin, required this.onLogout});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _pass = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  File? _imageFile;
  bool _isSaving = false;

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) setState(() => _imageFile = File(pickedFile.path));
  }

  Future<void> _addProduct() async {
    if (_nameCtrl.text.isEmpty || _priceCtrl.text.isEmpty || _imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Faltan datos o imagen')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      var request = http.MultipartRequest('POST', Uri.parse('https://aling-backend.onrender.com/api/products'));
      request.fields['name'] = _nameCtrl.text;
      request.fields['factoryPrice'] = _priceCtrl.text;
      request.files.add(await http.MultipartFile.fromPath('image', _imageFile!.path));

      var response = await request.send();
      if (response.statusCode == 201) {
        _nameCtrl.clear(); _priceCtrl.clear(); setState(() => _imageFile = null);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Producto guardado. Desliza en tienda para ver.')));
      }
    } catch (e) { debugPrint(e.toString()); }
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isAdmin) return _buildAdminPanel();
    if (widget.user != null) return _buildUserInfo();

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(35),
        child: Column(children: [
          const SizedBox(height: 60),
          const Icon(Icons.account_circle_outlined, size: 80, color: Colors.deepOrange),
          const SizedBox(height: 20),
          const Text('Iniciar Sesión', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const Text('Accede a tu cuenta de Aling Mayorista', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 40),
          TextField(controller: _email, decoration: const InputDecoration(labelText: 'Correo electrónico', border: OutlineInputBorder())),
          const SizedBox(height: 15),
          TextField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder())),
          const SizedBox(height: 25),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
            onPressed: () { if (_email.text == 'admin@aling.com' && _pass.text == 'admin123') widget.onLogin(null, true); },
            child: const Text('Entrar como Admin'),
          )),
          const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text('O')),
          SizedBox(width: double.infinity, height: 50, child: OutlinedButton.icon(
            icon: const Icon(Icons.login), label: const Text('Continuar con Google'),
            onPressed: () async {
              await GoogleSignIn().signOut(); 
              final u = await GoogleSignIn().signIn();
              if (u != null) widget.onLogin(u, false);
            },
          )),
        ]),
      ),
    );
  }

  Widget _buildAdminPanel() {
    return Scaffold(
      appBar: AppBar(title: const Text('Panel Admin'), actions: [
        IconButton(icon: const Icon(Icons.logout), onPressed: widget.onLogout)
      ]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Nuevo Producto', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
          const SizedBox(height: 20),
          TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
          const SizedBox(height: 15),
          TextField(controller: _priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Precio USD')),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 150, width: double.infinity,
              decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(10)),
              child: _imageFile == null 
                ? const Icon(Icons.add_a_photo, size: 40) 
                : Image.file(_imageFile!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 30),
          _isSaving ? const Center(child: CircularProgressIndicator()) : SizedBox(
            width: double.infinity, height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
              onPressed: _addProduct, 
              child: const Text('Subir a Cloudinary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildUserInfo() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      CircleAvatar(radius: 45, backgroundImage: NetworkImage(widget.user!.photoUrl ?? '')),
      const SizedBox(height: 15),
      Text(widget.user!.displayName ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
      const SizedBox(height: 35),
      ElevatedButton(onPressed: widget.onLogout, child: const Text('Cerrar Sesión'))
    ]));
  }
}

// --- CHECKOUT ---
class CheckoutScreen extends StatefulWidget {
  final double total;
  final String email;
  const CheckoutScreen({super.key, required this.total, required this.email});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool processing = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pago')),
      body: Center(
        child: processing ? const CircularProgressIndicator() : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
            const SizedBox(height: 20),
            Text('Total: \$${widget.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
              onPressed: () async {
                setState(() => processing = true);
                try {
                  await http.post(Uri.parse('https://aling-backend.onrender.com/api/checkout'),
                      headers: {'Content-Type': 'application/json'},
                      body: json.encode({'email': widget.email, 'totalAmount': widget.total.toStringAsFixed(2)}));
                  cartNotifier.value = [];
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Factura enviada al correo')));
                  }
                } catch (e) { debugPrint(e.toString()); }
                if (mounted) setState(() => processing = false);
              }, 
              child: const Text('Finalizar Pedido', style: TextStyle(fontSize: 18))
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/globals.dart';
import 'product_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List allProducts = [];
  List filteredProducts = [];
  final List<String> categories = [
    'Todos', 'Víveres', 'Tecnología', 'Hogar', 'Moda', 'Otros',
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
    setState(() { loading = true; error = null; });
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
      if (mounted) setState(() { error = "Conexión lenta con Aling. Reintenta."; loading = false; });
    }
  }

  void _applyFilter() {
    setState(() {
      if (selectedCategory == 'Todos') {
        filteredProducts = allProducts;
      } else {
        filteredProducts = allProducts.where((p) {
          String pCat = (p['category'] ?? 'Otros').toString().trim().toLowerCase();
          return pCat == selectedCategory.trim().toLowerCase();
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: SizedBox(
          width: 700,
          child: _SearchBar(allProducts: allProducts),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: load),
        ],
      ),
body: LayoutBuilder(
  builder: (context, constraints) {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selectedCategory == 'Todos' && !loading) _buildPromoCarousel(),
                  _buildCategoryChips(),
                  const SizedBox(height: 8),
                  _buildBody(),
                ],
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  },
),
    );
  }

  Widget _buildPromoCarousel() {
    return Container(
      height: 130,
      margin: const EdgeInsets.only(bottom: 10),
      child: PageView(
        children: [
          _buildPromoItem("Ofertas NovaMarket", "Mayorista en Riobamba", const Color(0xFFD10000)),
          _buildPromoItem("Nuevos Ingresos", "Tecnología y más", Colors.black87),
        ],
      ),
    );
  }

  Widget _buildPromoItem(String t, String s, Color c) {
    return Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(20)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
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
        padding: EdgeInsets.zero,
        itemCount: categories.length,
        itemBuilder: (ctx, i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ChoiceChip(
            label: Text(categories[i]),
            selected: selectedCategory == categories[i],
            selectedColor: const Color(0xFFD10000),
            labelStyle: TextStyle(
              color: selectedCategory == categories[i] ? Colors.white : Colors.black,
            ),
            onSelected: (v) => setState(() { selectedCategory = categories[i]; _applyFilter(); }),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (loading) return _buildSkeletonGrid();
    if (error != null) return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, size: 50, color: Colors.grey),
          Text(error!),
          ElevatedButton(onPressed: load, child: const Text("Reintentar")),
        ],
      ),
    );
    if (filteredProducts.isEmpty) return const Center(child: Text("No hay productos aquí."));

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 0.80,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: filteredProducts.length,
      itemBuilder: (ctx, i) => ProductCard(product: filteredProducts[i]),
    );
  }

  Widget _buildSkeletonGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 0.80,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: 10,
      itemBuilder: (ctx, i) => Container(
        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('NovaMarket', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                SizedBox(height: 6),
                Text('Mayorista en Riobamba', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Ayuda', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                SizedBox(height: 8),
                Text('Preguntas frecuentes', style: TextStyle(color: Colors.white54, fontSize: 12)),
                SizedBox(height: 4),
                Text('Contacto', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Empresa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                SizedBox(height: 8),
                Text('Acerca de NovaMarket', style: TextStyle(color: Colors.white54, fontSize: 12)),
                SizedBox(height: 4),
                Text('Términos y condiciones', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatefulWidget {
  final List allProducts;
  const _SearchBar({required this.allProducts});
  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final TextEditingController _controller = TextEditingController();
  List _results = [];
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlay;

  void _onChanged(String query) {
    if (query.isEmpty) {
      _removeOverlay();
      setState(() => _results = []);
      return;
    }
    setState(() {
      _results = widget.allProducts
          .where((p) => p['name'].toString().toLowerCase().contains(query.toLowerCase()))
          .take(6)
          .toList();
    });
    if (_results.isEmpty) {
      _removeOverlay();
    } else {
      _showOverlay();
    }
  }

  void _showOverlay() {
    _removeOverlay();
    _overlay = OverlayEntry(
      builder: (context) => Positioned(
        width: 500,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 48),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: _results.length,
              itemBuilder: (ctx, i) {
                final p = _results[i];
                return ListTile(
                  dense: true,
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      p['imageUrl'] ?? '',
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 36),
                    ),
                  ),
                  title: Text(p['name'] ?? '', style: const TextStyle(fontSize: 13)),
                  subtitle: Text('\$${p['factoryPrice']}',
                      style: const TextStyle(color: Colors.deepOrange, fontSize: 12)),
                  onTap: () {
                    _removeOverlay();
                    _controller.clear();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (c) => ProductDetailScreen(product: p),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  @override
  void dispose() {
    _removeOverlay();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: _controller,
        onChanged: _onChanged,
        decoration: InputDecoration(
          hintText: 'Buscar en NovaMarket...',
          hintStyle: TextStyle(color: Colors.black.withOpacity(0.75)),
          prefixIcon: const Icon(Icons.search, size: 20),
          prefixIconColor: Colors.grey,
          filled: true,
          fillColor: Colors.grey[100],
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFCCCCCC), width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFCCCCCC), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFAAAAAA), width: 1),
          ),
        ),
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  final dynamic product;
  const ProductCard({super.key, required this.product});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
        MaterialPageRoute(builder: (c) => ProductDetailScreen(product: product))),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
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
                  Text(product['name'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('\$${product['factoryPrice']}',
                    style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductSearchDelegate extends SearchDelegate {
  final List<dynamic> products;
  ProductSearchDelegate(this.products);
  @override
  String get searchFieldLabel => "Buscar en NovaMarket...";
  @override
  List<Widget>? buildActions(BuildContext context) =>
      [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];
  @override
  Widget? buildLeading(BuildContext context) =>
      IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));
  @override
  Widget buildResults(BuildContext context) => _buildList();
  @override
  Widget buildSuggestions(BuildContext context) => _buildList();

  Widget _buildList() {
    final results = products
        .where((p) => p['name'].toString().toLowerCase().contains(query.toLowerCase()))
        .toList();
    if (results.isEmpty) return const Center(child: Text("Sin resultados"));
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, childAspectRatio: 0.72,
        mainAxisSpacing: 16, crossAxisSpacing: 16,
      ),
      itemCount: results.length,
      itemBuilder: (ctx, i) => ProductCard(product: results[i]),
    );
  }
}
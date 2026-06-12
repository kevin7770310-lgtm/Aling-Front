import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

import '../utils/globals.dart';

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
            tabs: [Tab(text: 'Publicar'), Tab(text: 'Mis Productos')],
          ),
        ),
        body: const TabBarView(children: [VenderAddTab(), VenderManageTab()]),
      ),
    );
  }
}

// Pestaña para publicar un producto nuevo
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
    if (_nameCtrl.text.isEmpty || _priceCtrl.text.isEmpty || _imageFile == null) return;
    setState(() => _isSaving = true);
    try {
      var req = http.MultipartRequest(
        'POST', Uri.parse('https://aling-backend.onrender.com/api/products'));
      req.fields['name'] = _nameCtrl.text;
      req.fields['factoryPrice'] = double.tryParse(_priceCtrl.text)?.toStringAsFixed(2) ?? "0.00";
      req.fields['description'] = _descCtrl.text;
      req.fields['category'] = _selectedCategory;
      req.fields['sellerEmail'] = userNotifier.value?.email ?? '';
      if (kIsWeb) {
        req.files.add(http.MultipartFile.fromBytes(
          'image', await _imageFile!.readAsBytes(), filename: _imageFile!.name));
      } else {
        req.files.add(await http.MultipartFile.fromPath('image', _imageFile!.path));
      }
      await req.send();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Publicado correctamente')));
      _nameCtrl.clear(); _priceCtrl.clear(); _descCtrl.clear();
      setState(() => _imageFile = null);
    } catch (e) { debugPrint(e.toString()); }
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Área para seleccionar imagen desde la galería
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 180, width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.deepOrange.withOpacity(0.3)),
              ),
              child: _imageFile == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo, size: 40, color: Colors.deepOrange),
                        Text("Añadir Foto"),
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: kIsWeb
                          ? Image.network(_imageFile!.path, fit: BoxFit.cover)
                          : Image.file(File(_imageFile!.path), fit: BoxFit.cover),
                    ),
            ),
          ),
          const SizedBox(height: 20),
          TextField(controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder())),
          const SizedBox(height: 15),
          TextField(controller: _priceCtrl, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Precio \$', border: OutlineInputBorder())),
          const SizedBox(height: 15),
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            decoration: const InputDecoration(labelText: 'Categoría', border: OutlineInputBorder()),
            items: ['Víveres', 'Tecnología', 'Hogar', 'Moda', 'Otros']
                .map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (val) => setState(() => _selectedCategory = val!),
          ),
          const SizedBox(height: 15),
          TextField(controller: _descCtrl, maxLines: 3,
            decoration: const InputDecoration(labelText: 'Descripción', border: OutlineInputBorder())),
          const SizedBox(height: 25),
          _isSaving
              ? const CircularProgressIndicator()
              : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 55),
                    backgroundColor: Colors.deepOrange, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: _addProduct,
                  child: const Text('PUBLICAR PRODUCTO'),
                ),
        ],
      ),
    );
  }
}

// Pestaña para ver y editar los productos que ya publicaste
class VenderManageTab extends StatefulWidget {
  const VenderManageTab({super.key});
  @override
  State<VenderManageTab> createState() => _VenderManageTabState();
}

class _VenderManageTabState extends State<VenderManageTab> {
  List products = [];
  bool loading = true;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    if (!mounted) return;
    try {
      final res = await http.get(Uri.parse('https://aling-backend.onrender.com/api/products'));
      if (res.statusCode == 200) {
        List all = json.decode(res.body);
        if (mounted) setState(() {
          // Filtra solo los productos del usuario logueado
          products = all.where((p) => p['sellerEmail'] == userNotifier.value?.email).toList();
          loading = false;
        });
      }
    } catch (e) { debugPrint(e.toString()); }
  }

  void _editProduct(dynamic p) {
    final nameCtrl = TextEditingController(text: p['name']);
    final priceCtrl = TextEditingController(text: p['factoryPrice'].toString());
    final descCtrl = TextEditingController(text: p['description'] ?? '');
    String localCategory = p['category'] ?? 'Otros';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Editar Producto"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre')),
                TextField(controller: priceCtrl, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Precio')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: localCategory,
                  items: ['Víveres', 'Tecnología', 'Hogar', 'Moda', 'Otros']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (val) => setDialogState(() => localCategory = val!),
                  decoration: const InputDecoration(labelText: 'Categoría', border: OutlineInputBorder()),
                ),
                TextField(controller: descCtrl, maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Descripción')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
              onPressed: () async {
                final res = await http.put(
                  Uri.parse('https://aling-backend.onrender.com/api/products/${p['id']}'),
                  headers: {'Content-Type': 'application/json'},
                  body: json.encode({
                    'name': nameCtrl.text,
                    'factoryPrice': priceCtrl.text,
                    'description': descCtrl.text,
                    'category': localCategory,
                  }),
                );
                if (res.statusCode == 200) {
                  Navigator.pop(ctx);
                  load();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("✅ Actualizado")));
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
                  child: Image.network(products[i]['imageUrl'], width: 40, fit: BoxFit.cover),
                ),
                title: Text(products[i]['name']),
                subtitle: Text("\$${products[i]['factoryPrice']} • ${products[i]['category'] ?? 'Otros'}"),
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
                        final res = await http.delete(Uri.parse(
                          'https://aling-backend.onrender.com/api/products/${products[i]['id']}'));
                        if (res.statusCode == 200) load();
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
  }
}
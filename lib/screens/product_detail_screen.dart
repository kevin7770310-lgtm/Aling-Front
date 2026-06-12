import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/globals.dart';

class ProductDetailScreen extends StatelessWidget {
  final dynamic product;
  const ProductDetailScreen({super.key, required this.product});

  // Abre WhatsApp con un mensaje prellenado del producto
  void _whatsapp(BuildContext context) async {
    String phone = product['sellerPhone'] ?? '593982822157';
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Hubo un problema al abrir WhatsApp. Verifica que esté instalado."),
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
              height: 350, width: double.infinity, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 100),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product['name'] ?? '',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  Text('\$${product['factoryPrice']}',
                    style: const TextStyle(fontSize: 26, color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Chip(
                    label: Text(product['category'] ?? 'Otros'),
                    backgroundColor: Colors.orange.shade50,
                  ),
                  const Divider(height: 30),
                  const Text('Descripción',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(product['description'] ?? 'Sin descripción.',
                    style: const TextStyle(fontSize: 16)),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: () {
                  // Agrega el producto a la lista global del carrito
                  cartNotifier.value = List.from(cartNotifier.value)..add(product);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Agregado al carrito')),
                  );
                },
                child: const Text('AL CARRITO'),
              ),
            ),
            const SizedBox(width: 10),
            FloatingActionButton(
              backgroundColor: const Color(0xFF25D366),
              onPressed: () => _whatsapp(context),
              child: const Icon(Icons.chat, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
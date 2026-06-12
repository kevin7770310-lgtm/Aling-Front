import 'package:flutter/material.dart';

import '../utils/globals.dart';
import 'address_screen.dart';
import 'profile_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: userNotifier,
      builder: (context, user, _) {
        // Si no hay sesión, muestra pantalla de login requerido
        if (user == null) return const LoginRequiredScreen();

        return ValueListenableBuilder<List>(
          valueListenable: cartNotifier,
          builder: (ctx, list, _) {
            // Suma el total de todos los productos en el carrito
            double total = 0;
            for (var item in list) {
              total += double.tryParse(item['factoryPrice'].toString()) ?? 0;
            }

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
                            child: Image.network(list[i]['imageUrl'], width: 50, fit: BoxFit.cover),
                          ),
                          title: Text(list[i]['name']),
                          subtitle: Text('\$${list[i]['factoryPrice']}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            // Elimina el producto de la lista por su posición
                            onPressed: () => cartNotifier.value =
                                List.from(cartNotifier.value)..removeAt(i),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        onPressed: () => Navigator.push(context,
                          MaterialPageRoute(
                            builder: (c) => AddressScreen(total: total, email: user.email),
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
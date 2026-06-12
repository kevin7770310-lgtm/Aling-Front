import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/globals.dart';
import '../main.dart'; // para MainScreenState

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: userNotifier,
      builder: (context, user, _) {
        if (user == null) return _buildLogin(context);

        return Scaffold(
          appBar: AppBar(title: const Text('Mi Cuenta')),
          body: Column(
            children: [
              const SizedBox(height: 30),
              // Foto de perfil del usuario de Google
              CircleAvatar(
                radius: 50,
                backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
              ),
              const SizedBox(height: 15),
              Text(user.displayName ?? 'Usuario',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
                    await googleSignIn.signOut();
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

  // Pantalla de bienvenida cuando no hay sesión
  Widget _buildLogin(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shopping_bag_outlined, size: 100, color: Colors.deepOrange),
              const SizedBox(height: 30),
              const Text("Bienvenido a NovaMarket",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 50),
              ElevatedButton.icon(
                icon: const Icon(Icons.login),
                label: const Text("CONTINUAR CON GOOGLE"),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 55),
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: () async {
                  try {
                    final u = await googleSignIn.signIn();
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

// Pantalla que aparece cuando se requiere login para ver algo
class LoginRequiredScreen extends StatelessWidget {
  const LoginRequiredScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_circle_outlined, size: 100, color: Colors.deepOrange.shade100),
            const Text("Acceso Requerido",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ElevatedButton(
              // Navega a la pestaña de Perfil (índice 3) para que pueda hacer login
              onPressed: () {
                final mainState = context.findAncestorStateOfType<MainScreenState>();
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
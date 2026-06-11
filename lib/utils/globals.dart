import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// El carrito: lista de productos que el usuario ha agregado
final ValueNotifier<List<dynamic>> cartNotifier = ValueNotifier([]);

// El usuario logueado (null = no hay sesión)
final ValueNotifier<GoogleSignInAccount?> userNotifier = ValueNotifier(null);

// Configuración del login con Google
final GoogleSignIn googleSignIn = GoogleSignIn(
  clientId: kIsWeb
      ? "687685478470-5h6mt99nb61is3i45l8e28ncfvn3o129.apps.googleusercontent.com"
      : null,
  signInOption: SignInOption.standard,
  scopes: ['email', 'https://www.googleapis.com/auth/userinfo.profile'],
);
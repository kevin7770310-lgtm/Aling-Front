import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AddressScreen extends StatefulWidget {
  final String email;
  final double total;

  AddressScreen({required this.email, required this.total});

  @override
  _AddressScreenState createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  bool _isLoading = false;

  // Función para finalizar la compra enviando la dirección al backend de Render
  Future<void> _finalizarPedido() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final url = Uri.parse('https://aling-backend.onrender.com/api/checkout');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': widget.email,
          'totalAmount': widget.total.toStringAsFixed(2),
          'address': "${_addressController.text} (Ref: ${_referenceController.text})",
        }),
      );

      if (response.statusCode == 200) {
        _mostrarAlerta("¡Éxito!", "Pedido realizado. Revisa tu correo: ${widget.email}", Colors.green);
      } else {
        _mostrarAlerta("Error", "No se pudo procesar el pago.", Colors.red);
      }
    } catch (e) {
      _mostrarAlerta("Error de red", "Verifica tu conexión al servidor.", Colors.orange);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _mostrarAlerta(String titulo, String mensaje, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: color),
    );
    if (color == Colors.green) {
      Navigator.pop(context); // Regresa a la tienda tras el éxito
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Datos de Entrega"),
        backgroundColor: Colors.orange[800],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "¿Dónde entregamos tu pedido?",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange[900]),
                ),
                SizedBox(height: 20),
                TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    labelText: "Dirección de domicilio",
                    prefixIcon: Icon(Icons.home),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (value) => value!.isEmpty ? "Ingresa tu dirección" : null,
                ),
                SizedBox(height: 15),
                TextFormField(
                  controller: _referenceController,
                  decoration: InputDecoration(
                    labelText: "Referencia (Ej: Junto a la tienda azul)",
                    prefixIcon: Icon(Icons.explore),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (value) => value!.isEmpty ? "Agrega una referencia" : null,
                ),
                SizedBox(height: 30),
                Container(
                  padding: EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Total a pagar:", style: TextStyle(fontSize: 16)),
                      Text("\$${widget.total.toStringAsFixed(2)}", 
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange[800])),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _finalizarPedido,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[800],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isLoading 
                      ? CircularProgressIndicator(color: Colors.white) 
                      : Text("FINALIZAR Y ENVIAR FACTURA", style: TextStyle(fontSize: 16, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
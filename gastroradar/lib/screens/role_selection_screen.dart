import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'customer_screen.dart';
import 'restaurant_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  final _customerIdController = TextEditingController(text: '1');
  final _restaurantIdController = TextEditingController(text: '1');

  bool _isLoadingUser = false;
  bool _isLoadingRestaurant = false;
  final String backendUrl = 'http://10.0.2.2:8000';

  Future<void> _login(String role, int id) async {
    if (role == 'user') setState(() => _isLoadingUser = true);
    if (role == 'restaurant') setState(() => _isLoadingRestaurant = true);

    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/auth/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"id": id, "role": role}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final token = jsonDecode(response.body)['access_token'];
        if (role == 'user') {
          Navigator.push(context, MaterialPageRoute(builder: (context) => CustomerScreen(userId: id, token: token)));
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (context) => RestaurantScreen(restaurantId: id, token: token)));
        }
      } else {
        // Łapanie błędu braku konta - Poprawa ślepego ładowania
        final errorMsg = jsonDecode(response.body)['detail'] ?? 'Błąd logowania';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Błąd połączenia z serwerem.'), backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        if (role == 'user') setState(() => _isLoadingUser = false);
        if (role == 'restaurant') setState(() => _isLoadingRestaurant = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.local_pizza, size: 80, color: Colors.deepOrange),
                const SizedBox(height: 16),
                Text('GastroRadar', style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                const SizedBox(height: 48),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Text('Panel Klienta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        TextField(controller: _customerIdController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Twoje ID (np. 1)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_outline))),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity, height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _isLoadingUser ? null : () => _login('user', int.tryParse(_customerIdController.text) ?? 1),
                            icon: _isLoadingUser ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.person),
                            label: const Text('Zaloguj jako Klient'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Text('Panel Restauracji', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        TextField(controller: _restaurantIdController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'ID Lokalu (np. 1)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.storefront_outlined))),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity, height: 50,
                          child: OutlinedButton.icon(
                            onPressed: _isLoadingRestaurant ? null : () => _login('restaurant', int.tryParse(_restaurantIdController.text) ?? 1),
                            icon: _isLoadingRestaurant ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.storefront),
                            label: const Text('Zarządzaj Restauracją'),
                          ),
                        ),
                      ],
                    ),
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
import 'package:flutter/material.dart';
import 'customer_screen.dart';
import 'restaurant_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  // Kontrolery do pobierania wpisanych ID
  final _customerIdController = TextEditingController(text: '1');
  final _restaurantIdController = TextEditingController(text: '1');

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
                Text(
                  'GastroRadar',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange,
                      ),
                ),
                const SizedBox(height: 48),
                
                // --- SEKCJA KLIENTA ---
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Text('Panel Klienta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _customerIdController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Twoje ID użytkownika (np. 1)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // Pobieramy wpisane ID (jeśli puste, domyślnie 1)
                              final int uId = int.tryParse(_customerIdController.text) ?? 1;
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => CustomerScreen(userId: uId)),
                              );
                            },
                            icon: const Icon(Icons.person),
                            label: const Text('Zaloguj jako Klient'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // --- SEKCJA RESTAURACJI ---
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Text('Panel Restauracji', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _restaurantIdController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'ID Twojej restauracji (np. 1)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.storefront_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              // Pobieramy wpisane ID (jeśli puste, domyślnie 1)
                              final int rId = int.tryParse(_restaurantIdController.text) ?? 1;
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => RestaurantScreen(restaurantId: rId)),
                              );
                            },
                            icon: const Icon(Icons.storefront),
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
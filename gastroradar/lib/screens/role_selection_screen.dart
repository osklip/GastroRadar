import 'package:flutter/material.dart';
import 'customer_screen.dart';
import 'restaurant_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.local_pizza, size: 100, color: Colors.deepOrange),
                const SizedBox(height: 16),
                Text(
                  'GastroRadar',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange,
                      ),
                ),
                const SizedBox(height: 8),
                const Text('Wybierz, kim jesteś:', style: TextStyle(fontSize: 18, color: Colors.grey)),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CustomerScreen())),
                    icon: const Icon(Icons.person),
                    label: const Text('Jestem Klientem', style: TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RestaurantScreen())),
                    icon: const Icon(Icons.storefront),
                    label: const Text('Panel Restauracji', style: TextStyle(fontSize: 18)),
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
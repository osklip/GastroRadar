import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class RestaurantScreen extends StatefulWidget {
  const RestaurantScreen({super.key});

  @override
  State<RestaurantScreen> createState() => _RestaurantScreenState();
}

class _RestaurantScreenState extends State<RestaurantScreen> {
  final _foodController = TextEditingController(text: "Pizza Margherita");
  final _priceController = TextEditingController(text: "15.99");
  double _radius = 1000;
  bool _isLoading = false;

  final int restaurantId = 1;
  final String backendUrl = 'http://10.0.2.2:8000';

  Future<void> _sendFlashSale() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/restaurants/flash-sale'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "restaurant_id": restaurantId,
          "food_item": _foodController.text,
          "discount_price": double.tryParse(_priceController.text) ?? 0.0,
          "radius_meters": _radius.toInt(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Wysłano! Powiadomiono ${data["users_notified_count"]} osób w okolicy.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception("Błąd serwera");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wystąpił błąd podczas wysyłania.'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Panel Menedżera')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nowa szybka promocja', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            TextField(
              controller: _foodController,
              decoration: const InputDecoration(labelText: 'Co przeceniasz?', border: OutlineInputBorder(), prefixIcon: Icon(Icons.fastfood)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Nowa cena (PLN)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.attach_money)),
            ),
            const SizedBox(height: 24),
            Text('Zasięg powiadomień: ${_radius.toInt()} metrów', style: const TextStyle(fontWeight: FontWeight.bold)),
            Slider(
              value: _radius, min: 500, max: 5000, divisions: 9, label: '${_radius.toInt()} m',
              onChanged: (val) => setState(() => _radius = val),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _sendFlashSale,
                icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
                label: const Text('Wystrzel powiadomienia', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
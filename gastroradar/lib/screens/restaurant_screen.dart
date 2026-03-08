import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class RestaurantScreen extends StatefulWidget {
  final int restaurantId;
  const RestaurantScreen({super.key, required this.restaurantId});

  @override
  State<RestaurantScreen> createState() => _RestaurantScreenState();
}

class _RestaurantScreenState extends State<RestaurantScreen> {
  // Formularz nowej promocji
  final _foodController = TextEditingController(text: "Pizza Margherita");
  final _priceController = TextEditingController(text: "15.99");
  double _radius = 1000;
  double _durationMinutes = 30;
  bool _isLoading = false;

  // Lista aktywnych promocji pobranych z serwera
  List<dynamic> _activeSales = [];

  final String backendUrl = 'http://10.0.2.2:8000';

  @override
  void initState() {
    super.initState();
    _fetchActiveSales();
  }

  // Odpytuje FastAPI o trwające promocje (Punkt 4.1)
  Future<void> _fetchActiveSales() async {
    try {
      final response = await http.get(Uri.parse('$backendUrl/api/restaurants/active-sales/${widget.restaurantId}'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _activeSales = data['sales'] ?? [];
        });
      }
    } catch (e) {
      debugPrint("Błąd pobierania promocji: $e");
    }
  }

  // Skraca czas promocji (kończy ją natychmiast)
  Future<void> _cancelSale(int saleId) async {
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/restaurants/cancel-sale'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"restaurant_id": widget.restaurantId, "sale_id": saleId}),
      );
      if (response.statusCode == 200) {
        _fetchActiveSales(); // Odświeża listę po usunięciu
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Zakończono promocję.'), backgroundColor: Colors.orange));
      }
    } catch (e) {
      debugPrint("Błąd usuwania promocji: $e");
    }
  }

  // Wystrzeliwuje nową ofertę z ustawionym czasem (Punkt 4.2)
  Future<void> _sendFlashSale() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/restaurants/flash-sale'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "restaurant_id": widget.restaurantId,
          "food_item": _foodController.text,
          "discount_price": double.tryParse(_priceController.text) ?? 0.0,
          "radius_meters": _radius.toInt(),
          "duration_minutes": _durationMinutes.toInt(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _fetchActiveSales(); // Odświeża listę aktywnych!
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Wysłano! Powiadomiono ${data["users_notified_count"]} osób w okolicy.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception("Błąd serwera: ${response.statusCode}");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Wystąpił błąd: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Formatuje datę zwrotną odczytaną z serwera
  String _formatTime(String isoString) {
    DateTime dt = DateTime.parse(isoString).toLocal();
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Zarządzanie (ID: ${widget.restaurantId})'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.rocket_launch), text: "Nadaj"),
              Tab(icon: Icon(Icons.list_alt), text: "Aktywne"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // ZAKŁADKA 1: FORMULARZ NADAWANIA
            SingleChildScrollView(
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
                  
                  // Nowy suwak czasu trwania
                  Text('Czas trwania: ${_durationMinutes.toInt()} minut', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Slider(
                    value: _durationMinutes, min: 15, max: 120, divisions: 7, label: '${_durationMinutes.toInt()} min',
                    onChanged: (val) => setState(() => _durationMinutes = val),
                    activeColor: Colors.blueAccent,
                  ),
                  
                  const SizedBox(height: 8),
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
            
            // ZAKŁADKA 2: PODGLĄD AKTYWNYCH PROMOCJI
            RefreshIndicator(
              onRefresh: _fetchActiveSales,
              child: _activeSales.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.7,
                        alignment: Alignment.center,
                        child: const Text("Brak aktywnych promocji.", style: TextStyle(color: Colors.grey)),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _activeSales.length,
                      itemBuilder: (context, index) {
                        final sale = _activeSales[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            title: Text("${sale['food_item']} - ${sale['discount_price']} PLN"),
                            subtitle: Text("Zasięg: ${sale['radius_meters']}m\nWygasa o: ${_formatTime(sale['expires_at'])}"),
                            trailing: IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.red),
                              tooltip: "Zakończ natychmiast",
                              onPressed: () => _cancelSale(sale['id']),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
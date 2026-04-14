import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class RestaurantScreen extends StatefulWidget {
  final int restaurantId;
  final String token;
  const RestaurantScreen({super.key, required this.restaurantId, required this.token});

  @override
  State<RestaurantScreen> createState() => _RestaurantScreenState();
}

class _RestaurantScreenState extends State<RestaurantScreen> {
  final _foodController = TextEditingController(text: "Zestaw Lunchowy");
  final _priceController = TextEditingController(text: "19.99");
  final _limitController = TextEditingController(text: "50");
  
  double _radius = 1000;
  double _durationMinutes = 30;
  bool _isLoading = false;
  List<dynamic> _activeSales = [];
  final String backendUrl = 'http://10.0.2.2:8000';

  @override
  void initState() {
    super.initState();
    _fetchActiveSales();
  }

  Future<void> _fetchActiveSales() async {
    try {
      final response = await http.get(Uri.parse('$backendUrl/api/restaurants/active-sales'), headers: {"Authorization": "Bearer ${widget.token}"});
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() => _activeSales = jsonDecode(response.body)['sales'] ?? []);
        }
      }
    } catch (e) {
      debugPrint("Błąd pobierania ofert lokalu");
    }
  }

  Future<void> _sendFlashSale() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/restaurants/flash-sale'),
        headers: {"Content-Type": "application/json", "Authorization": "Bearer ${widget.token}"},
        body: jsonEncode({
          "food_item": _foodController.text,
          "discount_price": double.tryParse(_priceController.text) ?? 0.0,
          "radius_meters": _radius.toInt(),
          "duration_minutes": _durationMinutes.toInt(),
          "max_claims": int.tryParse(_limitController.text) ?? 50
        }),
      );

      if (response.statusCode == 200) {
        _fetchActiveSales();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Akcja rozpoczęta!'), backgroundColor: Colors.green));
      } else {
        if (!mounted) return;
        final msg = jsonDecode(response.body)['detail'] ?? 'Wystąpił błąd.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Błąd serwera.'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelSale(int saleId) async {
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/restaurants/cancel-sale'),
        headers: {"Content-Type": "application/json", "Authorization": "Bearer ${widget.token}"},
        body: jsonEncode({"sale_id": saleId}),
      );
      if (response.statusCode == 200) {
        _fetchActiveSales();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zakończono promocję.'), backgroundColor: Colors.orange));
      }
    } catch (e) {
      debugPrint("Błąd usuwania promocji");
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(title: const Text('Panel Lokalu'), bottom: const TabBar(tabs: [Tab(text: "Nadaj"), Tab(text: "Aktywne & Kody")])),
        body: TabBarView(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(controller: _foodController, decoration: const InputDecoration(labelText: 'Nazwa oferty', border: OutlineInputBorder())),
                  const SizedBox(height: 16),
                  TextField(controller: _priceController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Cena (PLN)', border: OutlineInputBorder())),
                  const SizedBox(height: 16),
                  TextField(controller: _limitController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Limit klientów (kuponów)', border: OutlineInputBorder())),
                  const SizedBox(height: 24),
                  Text('Czas trwania: ${_durationMinutes.toInt()} minut', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Slider(value: _durationMinutes, min: 15, max: 120, divisions: 7, label: '${_durationMinutes.toInt()} min', onChanged: (val) => setState(() => _durationMinutes = val)),
                  const SizedBox(height: 8),
                  Text('Zasięg radaru: ${_radius.toInt()} metrów', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Slider(value: _radius, min: 500, max: 5000, divisions: 9, label: '${_radius.toInt()} m', onChanged: (val) => setState(() => _radius = val)),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
                      onPressed: _isLoading ? null : _sendFlashSale, 
                      child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Uruchom Promocję')
                    ),
                  ),
                ],
              ),
            ),
            RefreshIndicator(
              onRefresh: _fetchActiveSales,
              child: _activeSales.isEmpty 
                ? SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(), child: Container(height: MediaQuery.of(context).size.height * 0.7, alignment: Alignment.center, child: const Text("Brak aktywnych promocji.", style: TextStyle(color: Colors.grey))))
                : ListView.builder(
                  itemCount: _activeSales.length,
                  itemBuilder: (context, index) {
                    final sale = _activeSales[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(sale['food_item'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                                IconButton(icon: const Icon(Icons.cancel, color: Colors.red), tooltip: "Zakończ przedwcześnie", onPressed: () => _cancelSale(sale['id'])),
                              ],
                            ),
                            Text("Wykorzystano: ${sale['current_claims']}/${sale['max_claims']} kuponów", style: TextStyle(color: sale['current_claims'] >= sale['max_claims'] ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Kod weryfikacyjny:", style: TextStyle(color: Colors.grey)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  color: Colors.grey.shade200,
                                  child: Text(sale['redemption_code'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 4)),
                                ),
                              ],
                            ),
                          ],
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
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class CustomerScreen extends StatefulWidget {
  final int userId;
  final String token;
  const CustomerScreen({super.key, required this.userId, required this.token});

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  final String backendUrl = 'http://10.0.2.2:8000';
  int _currentIndex = 0;
  
  List<dynamic> _activeDeals = [];
  List<dynamic> _myCoupons = [];
  List<Marker> _markers = []; // W flutter_map markery trzymamy jako List, a nie Set
  bool _isLoading = false;
  
  String _selectedCuisine = 'Wszystkie';
  final List<String> _cuisines = ['Wszystkie', 'Polska', 'Włoska', 'Azjatycka', 'Fast-food', 'Wege', 'Kebab'];

  StreamSubscription<Position>? _positionStreamSubscription;

  @override
  void initState() {
    super.initState();
    _setupFCMToken();
    _startTracking();
    _fetchData();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _setupFCMToken() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    try {
      String? token = await messaging.getToken();
      if (token != null) {
        await _sendTokenToBackend(token);
      }
      messaging.onTokenRefresh.listen((newToken) {
        _sendTokenToBackend(newToken);
      });
    } catch (e) {
      debugPrint("Błąd konfiguracji FCM: $e");
    }
  }

  Future<void> _sendTokenToBackend(String token) async {
    try {
      await http.post(
        Uri.parse('$backendUrl/api/users/fcm-token'),
        headers: {"Content-Type": "application/json", "Authorization": "Bearer ${widget.token}"},
        body: jsonEncode({"fcm_token": token}),
      );
    } catch (e) {
      debugPrint("Błąd tokenu FCM: $e");
    }
  }

  Future<void> _startTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
    }

    const LocationSettings settings = LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);
    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: settings).listen(
      (Position position) => _sendLocationToServer(position)
    );
    
    try {
      Position initialPos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _sendLocationToServer(initialPos);
    } catch (e) {
      debugPrint("Błąd pobrania pierwszej lokalizacji");
    }
  }

  Future<void> _sendLocationToServer(Position pos) async {
    try {
      await http.post(
        Uri.parse('$backendUrl/api/users/location'),
        headers: {"Content-Type": "application/json", "Authorization": "Bearer ${widget.token}"},
        body: jsonEncode({"lat": pos.latitude, "lon": pos.longitude}),
      );
    } catch (e) {
      debugPrint("Błąd wysyłania lokalizacji");
    }
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    await Future.wait([_fetchActiveDeals(), _fetchMyCoupons()]);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchActiveDeals() async {
    try {
      String url = '$backendUrl/api/restaurants/active-sales';
      if (_selectedCuisine != 'Wszystkie') {
        url += '?cuisine=${Uri.encodeComponent(_selectedCuisine)}';
      }
      
      final response = await http.get(Uri.parse(url), headers: {"Authorization": "Bearer ${widget.token}"});
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['sales'] ?? [];
        _activeDeals = data;
        
        // Generowanie znaczników dla darmowej mapy
        _markers = data.map<Marker>((s) => Marker(
          point: LatLng(s['lat'], s['lon']),
          width: 50,
          height: 50,
          child: GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("${s['food_item']} za ${s['discount_price']} PLN w lokalu ${s['restaurant_name']}"),
                  duration: const Duration(seconds: 3),
                  behavior: SnackBarBehavior.floating,
                )
              );
            },
            child: const Icon(Icons.location_on, color: Colors.deepOrange, size: 40),
          ),
        )).toList();
      }
    } catch (e) {
      debugPrint("Błąd pobierania ofert");
    }
  }

  Future<void> _fetchMyCoupons() async {
    try {
      final response = await http.get(
        Uri.parse('$backendUrl/api/users/my-coupons'),
        headers: {"Authorization": "Bearer ${widget.token}"},
      );
      if (response.statusCode == 200) {
        _myCoupons = jsonDecode(response.body)['coupons'] ?? [];
      }
    } catch (e) {
      debugPrint("Błąd pobierania kuponów");
    }
  }

  Future<void> _claimCoupon(int saleId) async {
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/users/claim-coupon'),
        headers: {"Content-Type": "application/json", "Authorization": "Bearer ${widget.token}"},
        body: jsonEncode({"sale_id": saleId}),
      );
      
      if (response.statusCode == 200) {
        await _fetchData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kupon odebrany! Sprawdź zakładkę Moje Kupony.'), backgroundColor: Colors.green));
      } else {
        if (!mounted) return;
        final msg = jsonDecode(response.body)['detail'] ?? 'Błąd';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Błąd połączenia'), backgroundColor: Colors.red));
    }
  }

  Widget _buildMapAndDeals() {
    return Column(
      children: [
        SizedBox(
          height: 250,
          child: FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(51.7592, 19.4560), // Centrum Łodzi
              initialZoom: 13.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.gastroradar', // Zgodne z regulaminem OSM
              ),
              MarkerLayer(
                markers: _markers,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              const Text('Kategoria: ', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String>(
                  value: _selectedCuisine,
                  isExpanded: true,
                  items: _cuisines.map((String value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() => _selectedCuisine = newValue);
                      _fetchData();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _activeDeals.isEmpty
            ? const Center(child: Text("Brak aktywnych ofert.", style: TextStyle(color: Colors.grey)))
            : RefreshIndicator(
                onRefresh: _fetchData,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: _activeDeals.length,
                  itemBuilder: (context, index) {
                    final deal = _activeDeals[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(deal['food_item'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("${deal['discount_price']} PLN • ${deal['restaurant_name']}"),
                        trailing: ElevatedButton(
                          onPressed: () => _claimCoupon(deal['id']),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
                          child: const Text('Odbierz'),
                        ),
                      ),
                    );
                  },
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildMyCoupons() {
    if (_myCoupons.isEmpty) {
      return const Center(child: Text("Nie odebrałeś jeszcze żadnego kuponu.", style: TextStyle(color: Colors.grey)));
    }
    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _myCoupons.length,
        itemBuilder: (context, index) {
          final coupon = _myCoupons[index];
          return Card(
            margin: const EdgeInsets.all(16),
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Text(coupon['restaurant_name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(coupon['food_item'], style: const TextStyle(fontSize: 22)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 32),
                    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.deepOrange, width: 2), borderRadius: BorderRadius.circular(8)),
                    child: Text(coupon['redemption_code'], style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 8)),
                  ),
                  const SizedBox(height: 16),
                  const Text("Pokaż ten kod obsłudze przy kasie", style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GastroRadar')),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : (_currentIndex == 0 ? _buildMapAndDeals() : _buildMyCoupons()),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Colors.deepOrange,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Odkrywaj'),
          BottomNavigationBarItem(icon: Icon(Icons.confirmation_num), label: 'Moje Kupony'),
        ],
      ),
    );
  }
}
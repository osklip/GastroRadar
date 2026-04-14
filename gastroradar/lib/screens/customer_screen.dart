import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class CustomerScreen extends StatefulWidget {
  final int userId;
  final String token;
  const CustomerScreen({super.key, required this.userId, required this.token});

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  String _statusMessage = 'Gotowy do szukania promocji...';
  bool _isTracking = false;
  StreamSubscription<Position>? _positionStreamSubscription;
  List<dynamic> _activeDeals = [];
  final String backendUrl = 'http://10.0.2.2:8000';
  
  String _selectedCuisine = 'Wszystkie';
  final List<String> _cuisines = ['Wszystkie', 'Polska', 'Włoska', 'Azjatycka', 'Fast-food', 'Wege', 'Kebab'];

  @override
  void initState() {
    super.initState();
    _setupFCMToken();
    _fetchActiveDeals();
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
      debugPrint("Błąd konfiguracji FCM: \$e");
    }
  }

  Future<void> _sendTokenToBackend(String token) async {
    try {
      await http.post(
        Uri.parse('\$backendUrl/api/users/fcm-token'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer \${widget.token}"
        },
        body: jsonEncode({"fcm_token": token}),
      );
    } catch (e) {
      debugPrint("Błąd aktualizacji tokenu FCM: \$e");
    }
  }

  Future<void> _fetchActiveDeals() async {
    try {
      String url = '\$backendUrl/api/restaurants/active-sales';
      if (_selectedCuisine != 'Wszystkie') {
        url += '?cuisine=\${Uri.encodeComponent(_selectedCuisine)}';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: {"Authorization": "Bearer \${widget.token}"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _activeDeals = data['sales'] ?? [];
        });
      }
    } catch (e) {
      debugPrint("Błąd pobierania ofert: \$e");
    }
  }

  Future<void> _startTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) { 
      setState(() => _statusMessage = 'Włącz GPS w telefonie.'); 
      return; 
    }
    
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) {
      setState(() => _statusMessage = 'Uprawnienia GPS zablokowane na stałe w ustawieniach systemu.');
      return;
    }

    setState(() { 
      _isTracking = true; 
      _statusMessage = 'Radar włączony. Nasłuchuję ruchu...'; 
    });

    const LocationSettings settings = LocationSettings(
      accuracy: LocationAccuracy.high, 
      distanceFilter: 10
    );
    
    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: settings).listen(
      (Position position) => _sendLocationToServer(position),
      onError: (error) => debugPrint("Błąd strumienia lokalizacji: \$error")
    );
    
    try {
      Position initialPos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _sendLocationToServer(initialPos);
    } catch (e) {
      debugPrint("Brak możliwości pobrania początkowej lokalizacji: \$e");
    }
  }

  void _stopTracking() {
    _positionStreamSubscription?.cancel();
    setState(() { 
      _isTracking = false; 
      _statusMessage = 'Radar wyłączony.'; 
    });
  }

  Future<void> _sendLocationToServer(Position pos) async {
    try {
      final response = await http.post(
        Uri.parse('\$backendUrl/api/users/location'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer \${widget.token}"
        },
        body: jsonEncode({"lat": pos.latitude, "lon": pos.longitude}),
      );

      if (response.statusCode == 401) {
        setState(() => _statusMessage = 'Sesja wygasła. Zaloguj się ponownie.');
        _stopTracking();
      }
    } catch (e) {
      debugPrint("Problem z połączeniem z serwerem baz danych: \$e");
    }
  }

  Future<void> _openMap(double lat, double lon) async {
    final Uri googleMapsUrl = Uri.parse('google.navigation:q=\$lat,\$lon&mode=w');
    if (!await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nie udało się otworzyć zewnętrznej nawigacji GPS.'), 
          backgroundColor: Colors.red
        )
      );
    }
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Radar Promocji (ID: \${widget.userId})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchActiveDeals,
            tooltip: 'Odśwież oferty',
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 4, 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Icon(
                      _isTracking ? Icons.radar : Icons.location_off, 
                      size: 64, 
                      color: _isTracking ? Colors.green : Colors.grey
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _statusMessage, 
                      textAlign: TextAlign.center, 
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isTracking ? _stopTracking : _startTracking,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isTracking ? Colors.red.shade100 : Colors.green.shade100, 
                        minimumSize: const Size(double.infinity, 50)
                      ),
                      child: Text(_isTracking ? 'Zatrzymaj radar' : 'Uruchom radar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                const Text('Kategoria kuchni: ', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedCuisine,
                    isExpanded: true,
                    items: _cuisines.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedCuisine = newValue;
                        });
                        _fetchActiveDeals();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _activeDeals.isEmpty
                ? const Center(
                    child: Text(
                      "Brak aktywnych ofert w tej kategorii.", 
                      style: TextStyle(color: Colors.grey, fontSize: 16)
                    )
                  )
                : RefreshIndicator(
                    onRefresh: _fetchActiveDeals,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _activeDeals.length,
                      itemBuilder: (context, index) {
                        final deal = _activeDeals[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Column(
                            children: [
                              ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: Colors.deepOrange, 
                                  child: Icon(Icons.fastfood, color: Colors.white)
                                ),
                                title: Text(
                                  "\${deal['food_item']} za \${deal['discount_price']} PLN", 
                                  style: const TextStyle(fontWeight: FontWeight.bold)
                                ),
                                subtitle: Text("Lokal: \${deal['restaurant_name']} (\${deal['cuisine_type']})"),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 16.0, bottom: 8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () { 
                                        if (deal['lat'] != null && deal['lon'] != null) {
                                          _openMap(deal['lat'], deal['lon']); 
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Brak danych GPS lokalu w bazie danych.'), 
                                              backgroundColor: Colors.orange
                                            )
                                          );
                                        }
                                      },
                                      icon: const Icon(Icons.map, color: Colors.blueAccent),
                                      label: const Text(
                                        'Nawiguj do Lokalu', 
                                        style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../main.dart'; 

class CustomerScreen extends StatefulWidget {
  // Zmienna przechowująca ID przekazane z ekranu logowania
  final int userId;
  
  const CustomerScreen({super.key, required this.userId});

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  String _statusMessage = 'Gotowy do szukania promocji...';
  bool _isTracking = false;
  Timer? _timer;
  List<dynamic> _activeDeals = [];
  
  final String backendUrl = 'http://10.0.2.2:8000'; 

  Future<void> _startTracking() async {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

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

    setState(() {
      _isTracking = true;
      _statusMessage = 'Radar włączony. Przeszukuję okolicę...';
    });

    _timer = Timer.periodic(const Duration(seconds: 15), (timer) => _sendLocationToServer());
    _sendLocationToServer();
  }

  void _stopTracking() {
    _timer?.cancel();
    setState(() {
      _isTracking = false;
      _statusMessage = 'Radar wyłączony.';
      _activeDeals.clear(); 
    });
  }

  Future<void> _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'gastro_radar_channel', 
      'GastroRadar Powiadomienia',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    
    await flutterLocalNotificationsPlugin.show(0, title, body, platformChannelSpecifics);
  }

  Future<void> _sendLocationToServer() async {
    try {
      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final response = await http.post(
        Uri.parse('$backendUrl/api/users/location'),
        headers: {"Content-Type": "application/json"},
        // Używamy dynamicznego ID z konstruktora widgetu
        body: jsonEncode({"user_id": widget.userId, "lat": pos.latitude, "lon": pos.longitude}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['alerts'] != null && (data['alerts'] as List).isNotEmpty) {
          for (String alertMsg in data['alerts']) {
            _showNotification('Złapano okazję!', alertMsg);
          }
        }

        setState(() {
          _activeDeals = data['deals'] ?? [];
          if (_activeDeals.isEmpty) {
            _statusMessage = 'Brak aktywnych okazji w zasięgu.';
          } else {
            _statusMessage = 'Znaleziono ${_activeDeals.length} okazji w okolicy!';
          }
        });
      }
    } catch (e) {
      debugPrint("Błąd komunikacji z serwerem: $e");
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Wyświetlamy ID na pasku tytułowym dla pewności
      appBar: AppBar(title: Text('Radar Promocji (ID: ${widget.userId})')),
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
                      color: _isTracking ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _statusMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isTracking ? _stopTracking : _startTracking,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isTracking ? Colors.red.shade100 : Colors.green.shade100,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: Text(_isTracking ? 'Zatrzymaj radar' : 'Uruchom radar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(),
          Expanded(
            child: _activeDeals.isEmpty
                ? const Center(
                    child: Text(
                      "Włącz radar lub poczekaj na nowe oferty...",
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    itemCount: _activeDeals.length,
                    itemBuilder: (context, index) {
                      final deal = _activeDeals[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.deepOrange,
                            child: Icon(Icons.fastfood, color: Colors.white),
                          ),
                          title: Text(
                            "${deal['item']} za ${deal['price']} PLN",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text("Lokal: ${deal['restaurant']}"),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.directions_walk, size: 20, color: Colors.grey),
                              Text("${deal['distance']} m", style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
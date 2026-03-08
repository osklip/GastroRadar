import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Inicjalizacja globalnego obiektu powiadomień
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Konfiguracja ikonki dla powiadomień (używamy domyślnej z Androida)
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
  
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  runApp(const GastroRadarApp());
}

class GastroRadarApp extends StatelessWidget {
  const GastroRadarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GastroRadar',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const RoleSelectionScreen(),
    );
  }
}

// ==========================================
// EKRAN 1: WYBÓR ROLI
// ==========================================
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

// ==========================================
// EKRAN 2: INTERFEJS KLIENTA (Odbiorca powiadomień)
// ==========================================
class CustomerScreen extends StatefulWidget {
  const CustomerScreen({super.key});

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  String _statusMessage = 'Gotowy do szukania promocji...';
  bool _isTracking = false;
  Timer? _timer;
  
  final int userId = 1;
  final String backendUrl = 'http://10.0.2.2:8000'; // Użyj IP komputera dla telefonu fizycznego

  Future<void> _startTracking() async {
    // Prośba o uprawnienia do powiadomień (Android 13+)
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

    // Pętla odpytująca serwer (tzw. polling)
    _timer = Timer.periodic(const Duration(seconds: 15), (timer) => _sendLocationToServer());
    _sendLocationToServer();
  }

  void _stopTracking() {
    _timer?.cancel();
    setState(() {
      _isTracking = false;
      _statusMessage = 'Radar wyłączony.';
    });
  }

  // Funkcja wywołująca natywne powiadomienie w systemie
  Future<void> _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'gastro_radar_channel', 
      'GastroRadar Powiadomienia',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    
    await flutterLocalNotificationsPlugin.show(
      0, title, body, platformChannelSpecifics,
    );
  }

  Future<void> _sendLocationToServer() async {
    try {
      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final response = await http.post(
        Uri.parse('$backendUrl/api/users/location'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"user_id": userId, "lat": pos.latitude, "lon": pos.longitude}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Serwer sam zadecydował, czy przesłać nam jakieś alerty
        if (data['alerts'] != null && (data['alerts'] as List).isNotEmpty) {
          for (String alertMsg in data['alerts']) {
            _showNotification('Złapano okazję!', alertMsg);
          }
        }
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
      appBar: AppBar(title: const Text('Radar Promocji')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Card(
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
                      style: const TextStyle(fontSize: 16),
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
          ],
        ),
      ),
    );
  }
}

// ==========================================
// EKRAN 3: INTERFEJS RESTAURACJI (Nadawca promocji)
// ==========================================
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
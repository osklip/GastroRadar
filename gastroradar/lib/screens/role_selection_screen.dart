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
  bool _isLoginMode = true; 
  String _selectedRole = 'user'; 

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  final String backendUrl = 'http://10.0.2.2:8000';

  Future<void> _submitForm() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wypełnij wszystkie pola!'), backgroundColor: Colors.red)
      );
      return;
    }

    if (!_isLoginMode && _passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hasło musi zawierać minimum 6 znaków.'), backgroundColor: Colors.orange)
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Rejestracja z poziomu aplikacji jest teraz możliwa wyłącznie dla klienta ('user')
      final endpoint = _isLoginMode ? '/api/auth/login' : '/api/auth/register/user';

      Map<String, dynamic> payload = {};

      if (_isLoginMode) {
        payload = {"username": _usernameController.text, "password": _passwordController.text, "role": _selectedRole};
      } else {
        payload = {"username": _usernameController.text, "password": _passwordController.text};
      }

      final response = await http.post(
        Uri.parse('$backendUrl$endpoint'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        if (_isLoginMode) {
          final data = jsonDecode(response.body);
          final token = data['access_token'];
          final id = data['id'];
          
          if (_selectedRole == 'user') {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => CustomerScreen(userId: id, token: token)));
          } else {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => RestaurantScreen(restaurantId: id, token: token)));
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Konto utworzone! Możesz się teraz zalogować.'), backgroundColor: Colors.green)
          );
          setState(() {
            _isLoginMode = true; 
            _passwordController.clear();
          });
        }
      } else {
        final errorMsg = jsonDecode(response.body)['detail'] ?? 'Błąd operacji';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red)
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd: ${e.toString().replaceAll('Exception: ', '')}'), backgroundColor: Colors.red)
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                const SizedBox(height: 32),
                
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'user', icon: Icon(Icons.person), label: Text('Klient')),
                    ButtonSegment(value: 'restaurant', icon: Icon(Icons.storefront), label: Text('Lokal')),
                  ],
                  selected: {_selectedRole},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() => _selectedRole = newSelection.first);
                  },
                ),
                
                const SizedBox(height: 32),
                
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    // Zmiana logiki UI: Pokazujemy formularz lub wizytówkę kontaktową
                    child: (!_isLoginMode && _selectedRole == 'restaurant') 
                      ? Column(
                          children: [
                            const Icon(Icons.handshake, size: 60, color: Colors.deepOrange),
                            const SizedBox(height: 16),
                            const Text('Zostań Partnerem!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            const Text(
                              'Dbamy o jakość ofert w naszej aplikacji. Aby dołączyć do platformy i publikować Flash Sales, skontaktuj się z naszym zespołem w celu nawiązania współpracy.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 15),
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.deepOrange.shade200),
                              ),
                              child: const SelectableText(
                                'wspolpraca@gastroradar.pl',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        )
                      : Column(
                          children: [
                            Text(
                              _isLoginMode ? 'Zaloguj się' : 'Utwórz nowe konto',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 24),
                            TextField(
                              controller: _usernameController,
                              decoration: InputDecoration(
                                labelText: _selectedRole == 'user' ? 'Nazwa użytkownika' : 'Nazwa lokalu',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.badge),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Hasło (min. 6 znaków)',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.lock),
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity, height: 50,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
                                onPressed: _isLoading ? null : _submitForm,
                                child: _isLoading 
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : Text(_isLoginMode ? 'ZALOGUJ' : 'ZAREJESTRUJ', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                  ),
                ),
                const SizedBox(height: 16),
                
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLoginMode = !_isLoginMode;
                      _passwordController.clear();
                    });
                  },
                  child: Text(
                    _isLoginMode ? "Nie masz konta? Zarejestruj się" : "Masz już konto? Zaloguj się",
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
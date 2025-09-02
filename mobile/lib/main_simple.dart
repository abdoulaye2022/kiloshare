import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const KiloShareApp());
}

class KiloShareApp extends StatelessWidget {
  const KiloShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KiloShare Auth Test',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _dio = Dio();
  bool _isLoading = false;
  String _message = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KiloShare - Test Auth'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.luggage,
              size: 80,
              color: Colors.orange,
            ),
            const SizedBox(height: 32),
            Text(
              'Test d\'authentification KiloShare',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Mot de passe',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _testRegister,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Test Inscription'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isLoading ? null : _testLogin,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Test Connexion'),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _testHealthCheck,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Test Santé Backend'),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _message,
                style: const TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testHealthCheck() async {
    setState(() {
      _message = 'Test de la connexion backend...';
    });

    try {
      final response = await _dio.get('http://127.0.0.1:8080/');
      setState(() {
        _message = 'Backend OK ✅\n${response.data}';
      });
    } catch (e) {
      setState(() {
        _message = 'Erreur backend ❌\n$e';
      });
    }
  }

  Future<void> _testRegister() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _message = 'Veuillez remplir email et mot de passe';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = 'Inscription en cours...';
    });

    try {
      final response = await _dio.post(
        'http://127.0.0.1:8080/api/v1/auth/register',
        data: {
          'email': _emailController.text,
          'password': _passwordController.text,
          'first_name': 'Test',
          'last_name': 'User',
        },
      );

      setState(() {
        _isLoading = false;
        _message = 'Inscription réussie ✅\n${response.data}';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        if (e is DioException && e.response != null) {
          _message = 'Erreur inscription ❌\n${e.response?.data}';
        } else {
          _message = 'Erreur inscription ❌\n$e';
        }
      });
    }
  }

  Future<void> _testLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _message = 'Veuillez remplir email et mot de passe';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = 'Connexion en cours...';
    });

    try {
      final response = await _dio.post(
        'http://127.0.0.1:8080/api/v1/auth/login',
        data: {
          'email': _emailController.text,
          'password': _passwordController.text,
        },
      );

      setState(() {
        _isLoading = false;
        _message = 'Connexion réussie ✅\n${response.data}';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        if (e is DioException && e.response != null) {
          _message = 'Erreur connexion ❌\n${e.response?.data}';
        } else {
          _message = 'Erreur connexion ❌\n$e';
        }
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

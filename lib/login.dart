import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'config.dart';
import 'dashboard.dart';
import 'register.dart';
import 'auth_ui.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showMessage('กรุณากรอก Username และ Password ให้ครบถ้วน');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/login.php'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final user = Map<String, dynamic>.from(data['user'] as Map? ?? {});
        user['access_token'] = data['access_token'];

        if (!mounted) return;

        final navigator = Navigator.of(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Login สำเร็จ')),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardPage(
              user: user,
              onLogout: () {
                navigator.pushAndRemoveUntil<void>(
                  MaterialPageRoute<void>(
                    builder: (context) => const LoginPage(),
                  ),
                  (route) => false,
                );
              },
            ),
          ),
        );
      } else {
        _showMessage(data['message'] ?? 'Username หรือ Password ไม่ถูกต้อง');
      }
    } catch (e) {
      _showMessage('ไม่สามารถเชื่อมต่อ API ได้: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthLayout(
        title: 'Welcome to MyMangaList',
        subtitle: 'กรุณาเข้าสู่ระบบเพื่อเริ่มต้นใช้งาน',
        headingTextAlign: TextAlign.center,
        children: [
          TextField(
            controller: _usernameController,
            decoration: authInputDecoration(
              context,
              label: 'Username',
              icon: Icons.person_outline_rounded,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: authInputDecoration(
              context,
              label: 'Password',
              icon: Icons.lock_outline_rounded,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: authPrimaryButtonStyle(context),
            onPressed: _isLoading ? null : _login,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('เข้าสู่ระบบ'),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RegisterPage()),
              );
            },
            child: const Text('ยังไม่มีบัญชี? สร้างบัญชีใหม่'),
          ),
        ],
      ),
    );
  }
}

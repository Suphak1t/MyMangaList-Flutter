import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'config.dart';
import 'auth_ui.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _isLoading = false;

  Future<void> _register() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (username.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showMessage('กรุณากรอกข้อมูลให้ครบถ้วน');
      return;
    }

    if (username.contains(' ')) {
      _showMessage('Username ต้องไม่มีช่องว่าง');
      return;
    }

    if (password != confirmPassword) {
      _showMessage('Password กับ Confirm Password ไม่ตรงกัน');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/register.php'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'confirm_password': confirmPassword,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'สมัครสมาชิกสำเร็จ')),
        );
        Navigator.pop(context);
      } else {
        _showMessage(data['message'] ?? 'สมัครสมาชิกไม่สำเร็จ');
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
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('สร้างบัญชีใหม่'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: AuthLayout(
        title: 'Create Your Account',
        subtitle: 'สร้างบัญชีสำหรับการใช้งาน MyMangaList',
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
          const SizedBox(height: 16),
          TextField(
            controller: _confirmPasswordController,
            obscureText: true,
            decoration: authInputDecoration(
              context,
              label: 'Confirm Password',
              icon: Icons.verified_user_outlined,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: authPrimaryButtonStyle(context),
            onPressed: _isLoading ? null : _register,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('สมัครสมาชิก'),
          ),
        ],
      ),
    );
  }
}

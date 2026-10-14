import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'config.dart';
import 'auth_ui.dart';

/// หน้าสมัครบัญชีทั่วไป; ไม่มีช่องเลือกบทบาทผู้ดูแล
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // controllers เก็บชื่อผู้ใช้ รหัสผ่าน และรหัสผ่านที่พิมพ์ซ้ำ
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _isLoading = false;

  // ตรวจข้อมูลฝั่งแอปก่อนส่ง username/password ไป register.php
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
      // server เป็นผู้สร้าง role=user เอง; แอปไม่ส่งค่า role
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/register.php'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'}, // บอก API ว่าส่ง JSON; สมัครสมาชิกยังไม่มี Bearer token
        body: jsonEncode({ // แปลงข้อมูลเป็น JSON สำหรับส่งให้ PHP API
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

  // แสดงผลสมัครหรือเหตุที่สมัครไม่สำเร็จผ่าน SnackBar
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
    // ใช้ AuthLayout เดียวกับ Login เพื่อให้รูปแบบสองหน้าสอดคล้องกัน
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
            controller: _usernameController, // อ่านและแก้ค่าชื่อผู้ใช้ในช่องนี้
            decoration: authInputDecoration( // เรียกฟังก์ชันตกแต่งช่องกรอกที่ใช้ร่วมกัน
              context, // ให้ฟังก์ชันอ่านสีช่องกรอกจาก Theme ปัจจุบัน
              label: 'Username', // ชื่อช่องสำหรับตั้งชื่อบัญชี
              icon: Icons.person_outline_rounded, // รูปคนด้านหน้าช่อง
            ),
          ),
          const SizedBox(height: 16), // เว้นระยะห่างแนวตั้ง 16 พิกเซล
          TextField(
            controller: _passwordController, // ผูกช่องนี้กับตัวแปรที่เก็บรหัสผ่าน
            obscureText: true, // ซ่อนตัวอักษรที่พิมพ์เพื่อไม่ให้เห็นรหัสผ่าน
            decoration: authInputDecoration( // เรียกฟังก์ชันตกแต่งช่องกรอกที่ใช้ร่วมกัน
              context, // ให้ฟังก์ชันอ่าน Theme ของหน้าสมัครสมาชิก
              label: 'Password', // ชื่อช่องสำหรับตั้งรหัสผ่าน
              icon: Icons.lock_outline_rounded, // รูปแม่กุญแจด้านหน้าช่อง
            ),
          ),
          const SizedBox(height: 16), // เว้นระยะห่างแนวตั้ง 16 พิกเซล
          TextField(
            controller: _confirmPasswordController, // เก็บรหัสผ่านที่พิมพ์ยืนยันอีกครั้ง
            obscureText: true, // ซ่อนตัวอักษรที่พิมพ์เพื่อไม่ให้เห็นรหัสผ่าน
            decoration: authInputDecoration( // เรียกฟังก์ชันตกแต่งช่องกรอกที่ใช้ร่วมกัน
              context, // ใช้ Theme เดียวกันกับช่องอื่นในฟอร์ม
              label: 'Confirm Password', // ชื่อช่องให้พิมพ์รหัสผ่านซ้ำ
              icon: Icons.verified_user_outlined, // ไอคอนสื่อการยืนยันรหัสผ่าน
            ),
          ),
          const SizedBox(height: 24), // เว้นระยะห่างแนวตั้ง 24 พิกเซล
          ElevatedButton(
            style: authPrimaryButtonStyle(context),
            onPressed: _isLoading ? null : _register, // ปิดปุ่มชั่วคราวเมื่อยังไม่พร้อม แล้วเรียกคำสั่งเมื่อกดได้
            child: _isLoading
                ? const SizedBox(
                    width: 20, // ความกว้างของพื้นที่แสดงหรือรูปภาพ
                    height: 20, // ความสูงของพื้นที่แสดงหรือรูปภาพ
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('สมัครสมาชิก'),
          ),
        ],
      ),
    );
  }
}

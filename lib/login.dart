import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'config.dart';
import 'dashboard.dart';
import 'register.dart';
import 'auth_ui.dart';

/// หน้าเข้าสู่ระบบ รับชื่อผู้ใช้และรหัสผ่านก่อนขอ token จาก API
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // controllers อ่านค่าจากสอง TextField; _isLoading กันการกดซ้ำระหว่างรอ API
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  // ตรวจช่องกรอก ส่ง JSON ไป login.php แล้วเปิด Dashboard เมื่อ server ยืนยันสำเร็จ
  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    // ไม่ส่งคำขอเมื่อข้อมูลจำเป็นยังไม่ครบ
    if (username.isEmpty || password.isEmpty) {
      _showMessage('กรุณากรอก Username และ Password ให้ครบถ้วน');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // ส่ง username/password เท่านั้น; role ต้องอ่านจากฐานข้อมูลฝั่ง server
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/login.php'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'}, // บอก API ว่า body เป็น JSON; ขั้น Login ยังไม่มี Bearer token
        body: jsonEncode({'username': username, 'password': password}), // แปลงข้อมูลเป็น JSON สำหรับส่งให้ PHP API
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final user = Map<String, dynamic>.from(data['user'] as Map? ?? {});
        // เก็บ token จากผลตอบกลับไว้ใน user map เพื่อส่งต่อให้หน้าที่เรียก API
        user['access_token'] = data['access_token'];

        if (!mounted) return;

        final navigator = Navigator.of(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Login สำเร็จ')),
        );

        // แทนหน้า Login ด้วย Dashboard เพื่อไม่ให้ปุ่ม Back กลับมาหน้าล็อกอิน
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

  // แจ้งผลตรวจฟอร์มหรือข้อผิดพลาดจาก API ที่ด้านล่างหน้าจอ
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
    // AuthLayout วางช่องกรอก ปุ่ม Login และทางไปสมัครสมาชิก
    return Scaffold(
      body: AuthLayout(
        title: 'Welcome to MyMangaList',
        subtitle: 'กรุณาเข้าสู่ระบบเพื่อเริ่มต้นใช้งาน',
        headingTextAlign: TextAlign.center,
        children: [
          TextField(
            controller: _usernameController, // อ่านและแก้ค่าชื่อผู้ใช้ในช่องนี้
            decoration: authInputDecoration( // เรียกฟังก์ชันตกแต่งช่องกรอกที่ใช้ร่วมกัน
              context, // ส่งตำแหน่ง widget เพื่อให้ฟังก์ชันอ่านสีจาก Theme ปัจจุบัน
              label: 'Username', // ข้อความชื่อช่องที่แสดงกับผู้ใช้
              icon: Icons.person_outline_rounded, // รูปคนด้านหน้าช่อง Username
            ),
          ),
          const SizedBox(height: 16), // เว้นระยะห่างแนวตั้ง 16 พิกเซล
          TextField(
            controller: _passwordController, // ผูกช่องนี้กับตัวแปรที่เก็บรหัสผ่าน
            obscureText: true, // ซ่อนตัวอักษรที่พิมพ์เพื่อไม่ให้เห็นรหัสผ่าน
            decoration: authInputDecoration( // เรียกฟังก์ชันตกแต่งช่องกรอกที่ใช้ร่วมกัน
              context, // ใช้ Theme ของหน้านี้กำหนดสีพื้นและขอบช่อง
              label: 'Password', // ข้อความชื่อช่องรหัสผ่าน
              icon: Icons.lock_outline_rounded, // รูปแม่กุญแจด้านหน้าช่อง
            ),
          ),
          const SizedBox(height: 24), // เว้นระยะห่างแนวตั้ง 24 พิกเซล
          ElevatedButton(
            style: authPrimaryButtonStyle(context),
            onPressed: _isLoading ? null : _login, // ปิดปุ่มชั่วคราวเมื่อยังไม่พร้อม แล้วเรียกคำสั่งเมื่อกดได้
            child: _isLoading
                ? const SizedBox(
                    width: 20, // ความกว้างของพื้นที่แสดงหรือรูปภาพ
                    height: 20, // ความสูงของพื้นที่แสดงหรือรูปภาพ
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('เข้าสู่ระบบ'),
          ),
          const SizedBox(height: 16), // เว้นระยะห่างแนวตั้ง 16 พิกเซล
          TextButton(
            onPressed: () { // กดแล้วเปิดหน้า RegisterPage
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

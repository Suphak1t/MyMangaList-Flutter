import 'package:flutter/material.dart';

import 'login.dart';
import 'theme_mode.dart';

/// จุดเริ่มแอป: ส่ง MyApp ให้ Flutter วาดหน้าจอ
void main() {
  runApp(const MyApp());
}

/// กำหนดธีมและหน้าเริ่มต้นร่วมของทั้งแอป
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ฟังค่าธีมเพื่อสร้าง MaterialApp ใหม่เมื่อผู้ใช้สลับโหมดสี
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, mode, child) => MaterialApp(
        title: 'MyMangaList',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        themeMode: mode,
        home: const LoginPage(),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// เก็บโหมดสีที่ทุกหน้ารับรู้ร่วมกันระหว่างเปิดแอป
final appThemeMode = ValueNotifier<ThemeMode>(ThemeMode.light);

/// สลับค่าธีมระหว่างสว่างกับมืดและแจ้ง widget ที่กำลังฟังอยู่
void toggleAppTheme() {
  appThemeMode.value = appThemeMode.value == ThemeMode.dark
      ? ThemeMode.light
      : ThemeMode.dark;
}

import 'package:flutter/material.dart';

final appThemeMode = ValueNotifier<ThemeMode>(ThemeMode.light);

void toggleAppTheme() {
  appThemeMode.value = appThemeMode.value == ThemeMode.dark
      ? ThemeMode.light
      : ThemeMode.dark;
}

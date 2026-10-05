// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lab6/add_manga_dialog.dart';
import 'package:lab6/main.dart';
import 'package:lab6/manga_detail.dart';

void main() {
  testWidgets('Login page renders the app entry point', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('MyMangaList'), findsOneWidget);
    expect(find.text('เข้าสู่ระบบ'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets('Add Manga form requires a title', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AddMangaDialog())),
    );

    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();

    expect(find.text('กรุณากรอกชื่อเรื่อง'), findsOneWidget);
  });

  testWidgets('Manga detail shows fields and asks before deletion', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MangaDetailPage(
          accessToken: 'test-token',
          manga: {
            'manga_id': 1,
            'title': 'Sample Manga',
            'author': 'Sample Author',
            'genre': 'Fantasy',
            'status': 'Reading',
            'description': 'Sample description',
          },
        ),
      ),
    );

    expect(find.text('Sample Manga'), findsOneWidget);
    expect(find.text('Sample description'), findsOneWidget);
    await tester.tap(find.text('ลบ'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ต้องการลบ'), findsOneWidget);
    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();
    expect(find.text('Sample Manga'), findsOneWidget);
  });
}

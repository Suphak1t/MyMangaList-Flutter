// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lab6/add_manga_dialog.dart';
import 'package:lab6/admin_dashboard.dart';
import 'package:lab6/chapter_dialog.dart';
import 'package:lab6/dashboard.dart';
import 'package:lab6/main.dart';
import 'package:lab6/manga_cover.dart';
import 'package:lab6/manga_detail.dart';
import 'package:lab6/manga_reader.dart';
import 'package:lab6/manga_search.dart';
import 'package:lab6/theme_mode.dart';

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

  testWidgets('Genre list can be searched', (tester) async {
    MangaFormResult? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                saved = await showDialog<MangaFormResult>(
                  context: context,
                  builder: (context) => const AddMangaDialog(),
                );
              },
              child: const Text('เปิดฟอร์ม'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('เปิดฟอร์ม'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เลือกแนวเรื่อง *'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'ค้นหาแนวเรื่อง'),
      'Rom',
    );
    await tester.pumpAndSettle();
    expect(find.text('Romance'), findsOneWidget);
    expect(find.text('Action'), findsNothing);
    await tester.tap(find.text('Romance'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'ค้นหาแนวเรื่อง'),
      'Action',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Action'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เสร็จ'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Romance'), findsWidgets);
    await tester.enterText(find.byType(TextFormField).first, 'New Manga');
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();
    expect(saved?.fields['title'], 'New Manga');
    expect(saved?.fields['genres'], containsAll(['Romance', 'Action']));
    expect(saved?.fields['release_status'], 'ongoing');
  });

  testWidgets('New Manga can start as Coming Soon', (tester) async {
    MangaFormResult? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => saved = await showDialog<MangaFormResult>(
                context: context,
                builder: (context) => const AddMangaDialog(),
              ),
              child: const Text('เปิดฟอร์ม'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('เปิดฟอร์ม'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Coming Manga');
    await tester.tap(find.text('เลือกแนวเรื่อง *'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Action'));
    await tester.tap(find.text('เสร็จ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ongoing'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coming Soon').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();
    expect(saved?.fields['release_status'], 'coming_soon');
  });

  testWidgets('Editing offers a separate release status', (tester) async {
    MangaFormResult? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => saved = await showDialog<MangaFormResult>(
                context: context,
                builder: (context) => const AddMangaDialog(
                  manga: {
                    'title': 'Existing Manga',
                    'genres': ['Action'],
                    'status': 'public',
                    'release_status': 'ongoing',
                  },
                ),
              ),
              child: const Text('เปิดฟอร์มแก้ไข'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('เปิดฟอร์มแก้ไข'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ongoing'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hiatus').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();
    expect(saved?.fields['release_status'], 'hiatus');
    expect(saved?.fields['status'], 'public');
  });

  testWidgets('A new chapter needs a PDF or images', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ChapterDialog(nextNumber: 1))),
    );
    expect(find.text('1'), findsOneWidget);
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();
    expect(find.text('กรุณาเลือก PDF หรือภาพของตอน'), findsOneWidget);
    expect(find.textContaining('PDF 1 ไฟล์ ไม่เกิน 20 MB'), findsOneWidget);
  });

  testWidgets('Manga detail shows fields and asks before deletion', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MangaDetailPage(
          accessToken: 'test-token',
          manga: {
            'manga_id': 1,
            'title': 'Sample Manga',
            'author': 'Sample Author',
            'genre': 'Fantasy',
            'status': 'private',
            'description': 'Sample description',
          },
        ),
      ),
    );

    expect(find.text('Sample Manga'), findsOneWidget);
    expect(find.text('Sample description'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(MangaCover)).dx,
      lessThan(tester.getTopLeft(find.text('Sample Manga')).dx),
    );
    expect(
      tester.getTopLeft(find.text('Sample description')).dy,
      greaterThan(tester.getTopLeft(find.byType(MangaCover)).dy),
    );
    await tester.scrollUntilVisible(find.text('ลบ'), 250);
    await tester.tap(find.text('ลบ'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ต้องการลบ'), findsOneWidget);
    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();
    expect(find.byType(MangaDetailPage), findsOneWidget);
  });

  testWidgets('Public Manga cannot be edited by another user', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MangaDetailPage(
          accessToken: 'test-token',
          canEdit: false,
          manga: {'manga_id': 2, 'title': 'Shared Manga', 'status': 'public'},
        ),
      ),
    );
    expect(find.text('Shared Manga'), findsOneWidget);
    expect(find.text('แก้ไข'), findsNothing);
    expect(find.text('ลบ'), findsNothing);
    await tester.scrollUntilVisible(find.text('รีพอร์ต Manga'), 250);
    expect(find.text('รีพอร์ต Manga'), findsOneWidget);
  });

  testWidgets('Admin panel shows user and report sections', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AdminDashboardPage(user: {'access_token': 'test-token'}),
      ),
    );
    expect(find.text('ผู้ใช้'), findsOneWidget);
    expect(find.text('รีพอร์ต'), findsOneWidget);
  });

  testWidgets('Reader shows previous chapter when available', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MangaReaderPage(
          mangaId: 1,
          chapterId: 2,
          title: 'ตอนที่ 2',
          accessToken: 'test-token',
          chapters: [
            {'chapter_id': 1, 'chapter_number': 1},
            {'chapter_id': 2, 'chapter_number': 2},
          ],
          chapterIndex: 1,
        ),
      ),
    );
    expect(find.text('ตอนก่อนหน้า'), findsOneWidget);
  });

  testWidgets('Search genres include categories without uploaded Manga', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MangaSearchPage(user: {'access_token': 'test-token'}),
      ),
    );
    await tester.tap(find.text('ประเภทการ์ตูน: ทุกแนว'));
    await tester.pumpAndSettle();
    expect(find.text('Action'), findsOneWidget);
    expect(find.text('Adventure'), findsOneWidget);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Action'));
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Adventure'));
    await tester.tap(find.text('เสร็จ'));
    await tester.pumpAndSettle();
    expect(find.text('ประเภทการ์ตูน: เลือก 2 แนว'), findsOneWidget);
  });

  testWidgets('Dashboard keeps local search only in My Manga', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DashboardPage(
          user: {
            'access_token': 'test-token',
            'user_id': 1,
            'username': 'Tester',
          },
        ),
      ),
    );
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('ไปหน้าค้นหาและกรอง Manga'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'สาธารณะ'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('ไปหน้าค้นหาและกรอง Manga'), findsOneWidget);
  });

  testWidgets('Theme can switch to dark mode', (tester) async {
    appThemeMode.value = ThemeMode.light;
    await tester.pumpWidget(const MyApp());
    toggleAppTheme();
    await tester.pump();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    appThemeMode.value = ThemeMode.light;
  });
}

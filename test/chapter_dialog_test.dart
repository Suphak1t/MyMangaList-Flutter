import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lab6/chapter_dialog.dart';

class _QueuedFilePicker extends FilePicker {
  final _results = <FilePickerResult>[];
  bool? lastAllowMultiple;

  void addImages(int start, int count) {
    _results.add(
      FilePickerResult([
        for (var number = start; number < start + count; number++)
          PlatformFile(
            path: '/images/$number.png',
            name: '${number.toString().padLeft(3, '0')}.png',
            size: 1024,
          ),
      ]),
    );
  }

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    lastAllowMultiple = allowMultiple;
    return _results.removeAt(0);
  }
}

void main() {
  testWidgets('Chapter keeps images selected in multiple rounds up to 15', (
    tester,
  ) async {
    final picker = _QueuedFilePicker();
    FilePicker.platform = picker;

    ChapterFormResult? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  saved = await showDialog<ChapterFormResult>(
                    context: context,
                    builder: (context) => const ChapterDialog(nextNumber: 1),
                  ),
              child: const Text('เปิดฟอร์ม'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('เปิดฟอร์ม'));
    await tester.pumpAndSettle();

    picker.addImages(1, 10);
    await tester.ensureVisible(find.text('เลือกภาพ'));
    await tester.tap(find.text('เลือกภาพ'));
    await tester.pumpAndSettle();
    expect(picker.lastAllowMultiple, isTrue);
    expect(find.text('ภาพที่เลือก 10/15 ไฟล์'), findsOneWidget);

    picker.addImages(11, 6);
    await tester.ensureVisible(find.text('เพิ่มภาพ (10/15)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เพิ่มภาพ (10/15)'));
    await tester.pumpAndSettle();
    expect(find.text('เลือกภาพได้สูงสุด 15 ไฟล์ต่อตอน'), findsOneWidget);
    expect(find.text('ภาพที่เลือก 10/15 ไฟล์'), findsOneWidget);

    picker.addImages(11, 5);
    await tester.ensureVisible(find.text('เพิ่มภาพ (10/15)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เพิ่มภาพ (10/15)'));
    await tester.pumpAndSettle();
    expect(find.text('ภาพที่เลือก 15/15 ไฟล์'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.ancestor(
              of: find.text('เพิ่มภาพ (15/15)'),
              matching: find.byWidgetPredicate(
                (widget) => widget is OutlinedButton,
              ),
            ),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();
    expect(saved?.contentType, 'images');
    expect(saved?.files, hasLength(15));
  });
}

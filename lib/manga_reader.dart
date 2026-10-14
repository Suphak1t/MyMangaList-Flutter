import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';

import 'config.dart';
import 'comments_page.dart';

/// หน้าอ่านรับเรื่อง ตอน รายการตอน และตำแหน่งตอนเพื่อเปลี่ยนตอนต่อเนื่อง
class MangaReaderPage extends StatefulWidget {
  const MangaReaderPage({
    super.key,
    required this.mangaId,
    required this.chapterId,
    required this.title,
    required this.accessToken,
    required this.chapters,
    required this.chapterIndex,
  });

  final int mangaId;
  final int chapterId;
  final String title;
  final String accessToken;
  final List<Map<String, dynamic>> chapters;
  final int chapterIndex;

  @override
  State<MangaReaderPage> createState() => _MangaReaderPageState();
}

class _MangaReaderPageState extends State<MangaReaderPage> {
  // State เก็บไฟล์ โหมดอ่าน ความกว้างหน้า และหน้าปัจจุบัน
  bool _loading = true;
  String? _error;
  String _type = 'none';
  List<Map<String, dynamic>> _files = [];
  PdfController? _pdfController;
  final PageController _imageController = PageController();
  bool _singlePage = false;
  bool _fitWidth = false;
  double _pageWidth = 700;
  int _currentPage = 1;
  int _pageCount = 0;
  // จำตำแหน่งและเวลาสัมผัสเพื่อแยกการแตะเปลี่ยนหน้าจากการลากเลื่อน
  int? _tapPointer;
  Offset? _tapStart;
  DateTime? _tapStartedAt;
  bool _tapMoved = false;

  // หาตอนถัดไปจาก chapterIndex โดยไม่ข้ามขอบรายการ
  Map<String, dynamic>? get _nextChapter =>
      widget.chapterIndex + 1 < widget.chapters.length
      ? widget.chapters[widget.chapterIndex + 1]
      : null;

  // แทนหน้าอ่านเดิมด้วยตอนที่เลือก โดยส่ง chapters และ token เดิมต่อไป
  void _openChapter(int index) {
    final chapter = widget.chapters[index];
    final chapterTitle = (chapter['title'] ?? '').toString();
    final title =
        'ตอนที่ ${chapter['chapter_number']}${chapterTitle.isEmpty ? '' : ' · $chapterTitle'}';
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MangaReaderPage(
          mangaId: widget.mangaId,
          chapterId: chapter['chapter_id'] as int,
          title: title,
          accessToken: widget.accessToken,
          chapters: widget.chapters,
          chapterIndex: index,
        ),
      ),
    );
  }

  // ทางลัดสำหรับปุ่มไปตอนถัดไป
  void _openNextChapter() => _openChapter(widget.chapterIndex + 1);

  // ทางลัดสำหรับปุ่มกลับตอนก่อนหน้า
  void _openPreviousChapter() => _openChapter(widget.chapterIndex - 1);

  // ทุกคำขอไฟล์และ metadata ของตอนต้องแนบ Bearer token
  Map<String, String> get _headers => {
    'Authorization': 'Bearer ${widget.accessToken}',
  };

  // แปลง file_id เป็น URL ที่ PHP จะตรวจสิทธิ์ก่อนส่ง PDF หรือภาพ
  Uri _fileUri(int fileId) =>
      Uri.parse('${ApiConfig.baseUrl}/manga_file.php?file_id=$fileId');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    _imageController.dispose();
    super.dispose();
  }

  // ขอชนิดและรายการไฟล์ของตอน; PDF ต้องโหลด bytes เพื่อสร้าง PdfController
  Future<void> _load() async {
    try {
      final response = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/chapter_files_get.php?chapter_id=${widget.chapterId}',
        ),
        headers: _headers, // ส่ง HTTP headers เช่น Bearer token ไปกับคำขอ
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || data['success'] != true) {
        throw Exception(data['message'] ?? 'เปิด Manga ไม่สำเร็จ');
      }
      final files = (data['files'] as List<dynamic>)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      final type = data['content_type'].toString();
      PdfController? pdfController;
      // pdfx เปิดข้อมูล PDF จาก bodyBytes หลัง API ส่งไฟล์สำเร็จ
      if (type == 'pdf' && files.isNotEmpty) {
        final pdfResponse = await http.get(
          _fileUri(files.first['file_id'] as int),
          headers: _headers, // ส่ง HTTP headers เช่น Bearer token ไปกับคำขอ
        );
        if (pdfResponse.statusCode != 200) {
          throw Exception('โหลด PDF ไม่สำเร็จ');
        }
        pdfController = PdfController(
          document: PdfDocument.openData(pdfResponse.bodyBytes),
        );
      }
      if (!mounted) {
        pdfController?.dispose();
        return;
      }
      setState(() {
        _files = files;
        _type = type;
        _pdfController = pdfController;
        _singlePage = type == 'pdf';
        _pageCount = type == 'images' ? files.length : 0;
        _loading = false;
      });
      _recordView();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  // บันทึกยอดชมหลังโหลดตอนสำเร็จ โดยไม่ขัดจังหวะการอ่านหากบันทึกพลาด
  Future<void> _recordView() async {
    try {
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/manga_view.php'),
        headers: {..._headers, 'Content-Type': 'application/json'}, // ส่ง HTTP headers เช่น Bearer token ไปกับคำขอ
        body: jsonEncode({'chapter_id': widget.chapterId}), // แปลงข้อมูลเป็น JSON สำหรับส่งให้ PHP API
      );
    } catch (_) {
      // A view-count problem must not interrupt reading.
    }
  }

  // กล่องตั้งค่าโหมดทีละหน้า/เลื่อนต่อเนื่องและความกว้างที่แสดง
  void _showSettings() {
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, updateDialog) => AlertDialog(
          title: const Text('ตั้งค่าการอ่าน'),
          content: SizedBox(
            width: 380, // ความกว้างของพื้นที่แสดงหรือรูปภาพ
            child: Column(
              mainAxisSize: MainAxisSize.min, // กำหนดให้ Row หรือ Column ใช้พื้นที่ตามเนื้อหาหรือเต็มแกน
              crossAxisAlignment: CrossAxisAlignment.start, // จัดแนวลูกตามแกนขวางของ Row หรือ Column
              children: [
                const Text('รูปแบบการอ่าน'),
                const SizedBox(height: 8), // เว้นระยะห่างแนวตั้ง 8 พิกเซล
                Wrap(
                  spacing: 8, // ระยะห่างระหว่าง widget ที่อยู่บรรทัดเดียวกัน
                  children: [
                    ChoiceChip(
                      label: const Text('เลื่อนลง'),
                      selected: !_singlePage, // กำหนดว่าชิปนี้อยู่ในสถานะเลือกหรือไม่
                      onSelected: (_) { // ทำงานเมื่อเลือกชิปนี้
                        setState(() => _singlePage = false);
                        updateDialog(() {});
                      },
                    ),
                    ChoiceChip(
                      label: const Text('ทีละหน้า'),
                      selected: _singlePage, // กำหนดว่าชิปนี้อยู่ในสถานะเลือกหรือไม่
                      onSelected: (_) { // ทำงานเมื่อเลือกชิปนี้
                        setState(() => _singlePage = true);
                        updateDialog(() {});
                      },
                    ),
                  ],
                ),
                if (_singlePage)
                  const Text(
                    'แตะครึ่งซ้ายเพื่อย้อนหน้า แตะครึ่งขวาเพื่อไปหน้าถัดไป',
                  ),
                const SizedBox(height: 16), // เว้นระยะห่างแนวตั้ง 16 พิกเซล
                Text('ความกว้างหน้า: ${_pageWidth.round()} px'),
                Slider(
                  value: _pageWidth, // ความกว้างหน้าการ์ตูนปัจจุบันของ Slider
                  min: 400,
                  max: 1200,
                  divisions: 8,
                  label: '${_pageWidth.round()} px',
                  onChanged: _fitWidth
                      ? null
                      : (value) {
                          setState(() => _pageWidth = value);
                          updateDialog(() {});
                        },
                ),
                SwitchListTile(
                  title: const Text('เต็มความกว้างหน้าต่าง'),
                  contentPadding: EdgeInsets.zero, // ระยะว่างภายในส่วนเนื้อหาของ widget
                  value: _fitWidth, // เปิดสวิตช์เมื่อให้หน้าการ์ตูนพอดีกับความกว้างจอ
                  onChanged: (value) { // ทำงานทันทีเมื่อค่าช่องหรือรายการเลือกเปลี่ยน
                    setState(() => _fitWidth = value);
                    updateDialog(() {});
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // ปิดหน้าหรือ dialog และส่งผลกลับ
              child: const Text('ปิด'),
            ),
          ],
        ),
      ),
    );
  }

  // เปลี่ยนเลขหน้าโดยจำกัดให้อยู่ระหว่างหน้าแรกกับหน้าสุดท้าย
  void _changePage(int direction) {
    if (_currentPage + direction < 1 || _currentPage + direction > _pageCount) {
      return;
    }
    if (_type == 'pdf') {
      if (direction < 0) {
        _pdfController?.previousPage(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _pdfController?.nextPage(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } else {
      _imageController.animateToPage(
        _currentPage - 1 + direction,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  // จับแตะครึ่งซ้ายเพื่อย้อนหน้าและครึ่งขวาเพื่อไปหน้าถัดไป
  Widget _tapToTurn(Widget child) => LayoutBuilder(
    builder: (context, constraints) => Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        if (_tapPointer != null) {
          _tapMoved = true;
          return;
        }
        _tapPointer = event.pointer;
        _tapStart = event.localPosition;
        _tapStartedAt = DateTime.now();
        _tapMoved = false;
      },
      onPointerMove: (event) {
        // ระยะลากเกิน 12 พิกเซลถือเป็นการเลื่อน ไม่เปลี่ยนหน้า
        if (event.pointer == _tapPointer &&
            _tapStart != null &&
            (event.localPosition - _tapStart!).distance > 12) {
          _tapMoved = true;
        }
      },
      onPointerUp: (event) {
        if (event.pointer != _tapPointer) return;
        // แตะต้องเร็วกว่า 500 ms และแทบไม่เคลื่อนที่
        final isTap =
            !_tapMoved &&
            _tapStart != null &&
            (event.localPosition - _tapStart!).distance <= 12 &&
            _tapStartedAt != null &&
            DateTime.now().difference(_tapStartedAt!).inMilliseconds < 500;
        _tapPointer = null;
        _tapStart = null;
        _tapStartedAt = null;
        if (isTap) {
          _changePage(
            event.localPosition.dx < constraints.maxWidth / 2 ? -1 : 1,
          );
        }
      },
      onPointerCancel: (event) {
        if (event.pointer == _tapPointer) {
          _tapPointer = null;
          _tapStart = null;
          _tapStartedAt = null;
        }
      },
      child: child,
    ),
  );

  // เลือกตัวแสดง PDF หรือภาพ และคำนวณความกว้างตามตัวเลือกการอ่าน
  Widget _reader() => LayoutBuilder(
    builder: (context, constraints) {
      final width = _fitWidth
          ? constraints.maxWidth
          : math.min(_pageWidth, constraints.maxWidth);
      // PDF ใช้ PdfView; ภาพใช้ Image.network ด้านล่าง
      if (_type == 'pdf') {
        return Center(
          child: SizedBox(
            width: width, // ความกว้างของพื้นที่แสดงหรือรูปภาพ
            height: constraints.maxHeight, // ความสูงของพื้นที่แสดงหรือรูปภาพ
            child: PdfView(
              controller: _pdfController!, // ให้ PdfView ควบคุมหน้า PDF ที่โหลดมา
              renderer: (page) {
                // pdfx normally renders at 2x as JPEG, which blurs small text.
                // Keep large pages within a reasonable memory budget.
                final scale = math.min(
                  3.0,
                  math.min(
                    8192 / math.max(page.width, page.height),
                    math.sqrt(12000000 / (page.width * page.height)),
                  ),
                );
                return page.render(
                  width: page.width * scale, // ความกว้างของพื้นที่แสดงหรือรูปภาพ
                  height: page.height * scale, // ความสูงของพื้นที่แสดงหรือรูปภาพ
                  format: PdfPageImageFormat.png,
                );
              },
              scrollDirection: _singlePage ? Axis.horizontal : Axis.vertical, // กำหนดทิศทางเลื่อนหน้าอ่าน
              pageSnapping: _singlePage, // ให้การเลื่อนหยุดพอดีทีละหน้าเมื่อเปิดโหมดนั้น
              onDocumentLoaded: (document) { // รับจำนวนหน้าหลังเปิดเอกสาร PDF สำเร็จ
                if (mounted) setState(() => _pageCount = document.pagesCount);
              },
              onPageChanged: (page) { // อัปเดตเลขหน้าปัจจุบันเมื่อเลื่อนหน้า
                if (mounted) setState(() => _currentPage = page);
              },
            ),
          ),
        );
      }

      // สร้างภาพหนึ่งหน้าจาก file_id พร้อม token และขนาดที่ตั้งไว้
      Widget imageAt(int index) => Center(
        child: Image.network(
          _fileUri(_files[index]['file_id'] as int).toString(),
          headers: _headers, // ส่ง HTTP headers เช่น Bearer token ไปกับคำขอ
          width: width, // ความกว้างของพื้นที่แสดงหรือรูปภาพ
          fit: BoxFit.fitWidth, // วิธีปรับภาพให้พอดีกับพื้นที่แสดง
          errorBuilder: (context, error, stackTrace) => const Padding(
            padding: EdgeInsets.all(24), // ระยะว่างด้านในระหว่างขอบกับเนื้อหา
            child: Text('โหลดภาพไม่สำเร็จ'),
          ),
        ),
      );

      // โหมดทีละหน้าใช้ PageView; โหมดต่อเนื่องใช้ ListView
      if (_singlePage) {
        return PageView.builder(
          controller: _imageController, // ควบคุมตำแหน่งหน้าภาพใน PageView
          itemCount: _files.length, // จำนวนรายการที่ ListView หรือ PageView ต้องสร้าง
          onPageChanged: (index) => setState(() => _currentPage = index + 1), // อัปเดตเลขหน้าปัจจุบันเมื่อเลื่อนหน้า
          itemBuilder: (context, index) =>
              SingleChildScrollView(child: imageAt(index)),
        );
      }
      return ListView.builder(
        itemCount:
            _files.length +
            (widget.chapterIndex > 0 || _nextChapter != null ? 1 : 0),
        itemBuilder: (context, index) => index == _files.length
            ? Padding(
                padding: const EdgeInsets.all(24), // ระยะว่างด้านในระหว่างขอบกับเนื้อหา
                child: Center(
                  child: Wrap(
                    alignment: WrapAlignment.center, // ตำแหน่งวางเนื้อหาภายในพื้นที่ของ widget
                    spacing: 12, // ระยะห่างระหว่าง widget ที่อยู่บรรทัดเดียวกัน
                    runSpacing: 8, // ระยะห่างระหว่างบรรทัดเมื่อ Wrap ขึ้นบรรทัดใหม่
                    children: [
                      if (widget.chapterIndex > 0)
                        OutlinedButton.icon(
                          onPressed: _openPreviousChapter, // เรียก callback นี้เมื่อผู้ใช้กดปุ่ม
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('ตอนก่อนหน้า'),
                        ),
                      if (_nextChapter != null)
                        FilledButton.icon(
                          onPressed: _openNextChapter, // เรียก callback นี้เมื่อผู้ใช้กดปุ่ม
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('ตอนถัดไป'),
                        ),
                    ],
                  ),
                ),
              )
            : imageAt(index),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    // เลือกเนื้อหากลางหน้าตามสถานะการโหลดก่อนสร้าง Scaffold
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(child: Text(_error!));
    } else if (_files.isEmpty) {
      body = const Center(child: Text('เรื่องนี้ยังไม่มีไฟล์ให้อ่าน'));
    } else {
      body = _reader();
      if (_singlePage && _pageCount > 0) body = _tapToTurn(body);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          // ปุ่มย้อนตอนอยู่แถบเดียวกับปุ่มตอนถัดไปในโหมดทีละหน้า/PDF
          if (widget.chapterIndex > 0 &&
              (_loading || _type == 'pdf' || _singlePage))
            TextButton.icon(
              onPressed: _openPreviousChapter, // เรียก callback นี้เมื่อผู้ใช้กดปุ่ม
              icon: const Icon(Icons.arrow_back),
              label: const Text('ตอนก่อนหน้า'),
            ),
          // ปุ่มตอนถัดไปปรากฏเมื่ออ่านถึงหน้าสุดท้ายของตอนนี้
          if (_nextChapter != null &&
              _pageCount > 0 &&
              _currentPage == _pageCount &&
              (_type == 'pdf' || _singlePage))
            TextButton.icon(
              onPressed: _openNextChapter, // เรียก callback นี้เมื่อผู้ใช้กดปุ่ม
              icon: const Icon(Icons.arrow_forward),
              label: const Text('ตอนถัดไป'),
            ),
          IconButton(
            tooltip: 'ความคิดเห็นของตอน',
            onPressed: () => Navigator.push( // เปิดหน้าใหม่เมื่อกดปุ่ม
              context,
              MaterialPageRoute(
                builder: (context) => CommentsPage(
                  mangaId: widget.mangaId,
                  chapterId: widget.chapterId,
                  title: 'ความคิดเห็นของตอน',
                  accessToken: widget.accessToken,
                ),
              ),
            ),
            icon: const Icon(Icons.comment_outlined),
          ),
          IconButton(
            tooltip: 'ตั้งค่าการอ่าน',
            onPressed: _loading || _error != null ? null : _showSettings, // ปิดปุ่มชั่วคราวเมื่อยังไม่พร้อม แล้วเรียกคำสั่งเมื่อกดได้
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: body,
    );
  }
}

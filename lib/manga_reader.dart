import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';

import 'config.dart';
import 'comments_page.dart';

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
  int? _tapPointer;
  Offset? _tapStart;
  DateTime? _tapStartedAt;
  bool _tapMoved = false;

  Map<String, dynamic>? get _nextChapter =>
      widget.chapterIndex + 1 < widget.chapters.length
      ? widget.chapters[widget.chapterIndex + 1]
      : null;

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

  void _openNextChapter() => _openChapter(widget.chapterIndex + 1);

  void _openPreviousChapter() => _openChapter(widget.chapterIndex - 1);

  Map<String, String> get _headers => {
    'Authorization': 'Bearer ${widget.accessToken}',
  };

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

  Future<void> _load() async {
    try {
      final response = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/chapter_files_get.php?chapter_id=${widget.chapterId}',
        ),
        headers: _headers,
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
      if (type == 'pdf' && files.isNotEmpty) {
        final pdfResponse = await http.get(
          _fileUri(files.first['file_id'] as int),
          headers: _headers,
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

  Future<void> _recordView() async {
    try {
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/manga_view.php'),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode({'chapter_id': widget.chapterId}),
      );
    } catch (_) {
      // A view-count problem must not interrupt reading.
    }
  }

  void _showSettings() {
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, updateDialog) => AlertDialog(
          title: const Text('ตั้งค่าการอ่าน'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('รูปแบบการอ่าน'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('เลื่อนลง'),
                      selected: !_singlePage,
                      onSelected: (_) {
                        setState(() => _singlePage = false);
                        updateDialog(() {});
                      },
                    ),
                    ChoiceChip(
                      label: const Text('ทีละหน้า'),
                      selected: _singlePage,
                      onSelected: (_) {
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
                const SizedBox(height: 16),
                Text('ความกว้างหน้า: ${_pageWidth.round()} px'),
                Slider(
                  value: _pageWidth,
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
                  contentPadding: EdgeInsets.zero,
                  value: _fitWidth,
                  onChanged: (value) {
                    setState(() => _fitWidth = value);
                    updateDialog(() {});
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ปิด'),
            ),
          ],
        ),
      ),
    );
  }

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
        if (event.pointer == _tapPointer &&
            _tapStart != null &&
            (event.localPosition - _tapStart!).distance > 12) {
          _tapMoved = true;
        }
      },
      onPointerUp: (event) {
        if (event.pointer != _tapPointer) return;
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

  Widget _reader() => LayoutBuilder(
    builder: (context, constraints) {
      final width = _fitWidth
          ? constraints.maxWidth
          : math.min(_pageWidth, constraints.maxWidth);
      if (_type == 'pdf') {
        return Center(
          child: SizedBox(
            width: width,
            height: constraints.maxHeight,
            child: PdfView(
              controller: _pdfController!,
              scrollDirection: _singlePage ? Axis.horizontal : Axis.vertical,
              pageSnapping: _singlePage,
              onDocumentLoaded: (document) {
                if (mounted) setState(() => _pageCount = document.pagesCount);
              },
              onPageChanged: (page) {
                if (mounted) setState(() => _currentPage = page);
              },
            ),
          ),
        );
      }

      Widget imageAt(int index) => Center(
        child: Image.network(
          _fileUri(_files[index]['file_id'] as int).toString(),
          headers: _headers,
          width: width,
          fit: BoxFit.fitWidth,
          errorBuilder: (context, error, stackTrace) => const Padding(
            padding: EdgeInsets.all(24),
            child: Text('โหลดภาพไม่สำเร็จ'),
          ),
        ),
      );

      if (_singlePage) {
        return PageView.builder(
          controller: _imageController,
          itemCount: _files.length,
          onPageChanged: (index) => setState(() => _currentPage = index + 1),
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
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      if (widget.chapterIndex > 0)
                        OutlinedButton.icon(
                          onPressed: _openPreviousChapter,
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('ตอนก่อนหน้า'),
                        ),
                      if (_nextChapter != null)
                        FilledButton.icon(
                          onPressed: _openNextChapter,
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
          if (widget.chapterIndex > 0 &&
              (_loading || _type == 'pdf' || _singlePage))
            TextButton.icon(
              onPressed: _openPreviousChapter,
              icon: const Icon(Icons.arrow_back),
              label: const Text('ตอนก่อนหน้า'),
            ),
          if (_nextChapter != null &&
              _pageCount > 0 &&
              _currentPage == _pageCount &&
              (_type == 'pdf' || _singlePage))
            TextButton.icon(
              onPressed: _openNextChapter,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('ตอนถัดไป'),
            ),
          IconButton(
            tooltip: 'ความคิดเห็นของตอน',
            onPressed: () => Navigator.push(
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
            onPressed: _loading || _error != null ? null : _showSettings,
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: body,
    );
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'add_manga_dialog.dart';
import 'chapter_dialog.dart';
import 'chapter_upload.dart';
import 'comments_page.dart';
import 'config.dart';
import 'manga_card.dart';
import 'manga_cover.dart';
import 'manga_reader.dart';

class MangaDetailPage extends StatefulWidget {
  const MangaDetailPage({
    super.key,
    required this.manga,
    required this.accessToken,
    this.canEdit = true,
    this.canReport = true,
  });

  final Map<String, dynamic> manga;
  final String accessToken;
  final bool canEdit;
  final bool canReport;

  @override
  State<MangaDetailPage> createState() => _MangaDetailPageState();
}

class _MangaDetailPageState extends State<MangaDetailPage> {
  late Map<String, dynamic> _manga = Map<String, dynamic>.from(widget.manga);
  List<Map<String, dynamic>> _chapters = [];
  bool _loadingChapters = true;
  String? _chapterError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadChapters();
  }

  Future<Map<String, dynamic>> _request(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/$endpoint'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer ${widget.accessToken}',
      },
      body: jsonEncode(body),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'บันทึกข้อมูลไม่สำเร็จ');
    }
    return data;
  }

  Future<void> _loadChapters() async {
    try {
      final response = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/chapters_get.php?manga_id=${_manga['manga_id']}',
        ),
        headers: {'Authorization': 'Bearer ${widget.accessToken}'},
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || data['success'] != true) {
        throw Exception(data['message'] ?? 'โหลดรายการตอนไม่สำเร็จ');
      }
      if (!mounted) return;
      setState(() {
        _chapters = (data['chapters'] as List<dynamic>)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        _chapterError = null;
        _loadingChapters = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _chapterError = error.toString().replaceFirst('Exception: ', '');
        _loadingChapters = false;
      });
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
    );
  }

  Future<void> _edit() async {
    final changes = await showDialog<MangaFormResult>(
      context: context,
      builder: (context) => AddMangaDialog(manga: _manga),
    );
    if (changes == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await _request('manga_update.php', {
        'manga_id': _manga['manga_id'],
        ...changes.fields,
      });
      if (!mounted) return;
      setState(
        () => _manga = {
          ..._manga,
          ...changes.fields,
          'genre': (changes.fields['genres'] as List).first,
        },
      );
      if (changes.coverFile != null) {
        try {
          final coverFilename = await uploadMangaCover(
            _manga['manga_id'] as int,
            changes.coverFile!,
            widget.accessToken,
          );
          if (mounted) setState(() => _manga['cover_filename'] = coverFilename);
        } catch (error) {
          _showError('บันทึกข้อมูลแล้ว แต่ภาพปกไม่สำเร็จ: $error');
          return;
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('แก้ไข Manga สำเร็จ')));
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveChapter([Map<String, dynamic>? oldChapter]) async {
    final nextNumber =
        _chapters.fold<int>(0, (max, chapter) {
          final number = chapter['chapter_number'] as int;
          return number > max ? number : max;
        }) +
        1;
    final result = await showDialog<ChapterFormResult>(
      context: context,
      builder: (context) =>
          ChapterDialog(nextNumber: nextNumber, chapter: oldChapter),
    );
    if (result == null || !mounted) return;
    if (_chapters.any(
      (chapter) =>
          chapter['chapter_number'] == result.number &&
          chapter['chapter_id'] != oldChapter?['chapter_id'],
    )) {
      _showError('เลขตอนนี้มีแล้ว');
      return;
    }
    setState(() => _busy = true);
    bool created = false;
    try {
      int chapterId;
      if (oldChapter == null) {
        final data = await _request('chapter_add.php', {
          'manga_id': _manga['manga_id'],
          'chapter_number': result.number,
          'title': result.title,
        });
        chapterId = (data['chapter_id'] as num).toInt();
        created = true;
      } else {
        chapterId = oldChapter['chapter_id'] as int;
      }
      if (result.files.isNotEmpty) {
        await uploadChapterFiles(chapterId, result, widget.accessToken);
      }
      await _request('chapter_update.php', {
        'chapter_id': chapterId,
        'chapter_number': result.number,
        'title': result.title,
        'is_published': result.published,
      });
      await _loadChapters();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('บันทึกตอนสำเร็จ')));
    } catch (error) {
      await _loadChapters();
      _showError(
        created
            ? 'สร้างตอนเป็นฉบับร่างแล้ว แต่ขั้นตอนถัดไปไม่สำเร็จ: $error'
            : error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteChapter(Map<String, dynamic> chapter) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบตอน'),
        content: Text('ต้องการลบตอนที่ ${chapter['chapter_number']} หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _request('chapter_delete.php', {
        'chapter_id': chapter['chapter_id'],
      });
      await _loadChapters();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _report() async {
    final formKey = GlobalKey<FormState>();
    String reasonText = '';
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('รีพอร์ต Manga'),
        content: Form(
          key: formKey,
          child: TextFormField(
            onChanged: (value) => reasonText = value,
            minLines: 3,
            maxLines: 5,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'เหตุผลที่ต้องการให้ผู้ดูแลตรวจสอบ',
              border: OutlineInputBorder(),
            ),
            validator: (value) => (value?.trim().length ?? 0) < 10
                ? 'กรุณาระบุเหตุผลอย่างน้อย 10 ตัวอักษร'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, reasonText.trim());
              }
            },
            child: const Text('ส่งรีพอร์ต'),
          ),
        ],
      ),
    );
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final data = await _request('report_manga.php', {
        'manga_id': _manga['manga_id'],
        'reason': reason,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message'] ?? 'ส่งรีพอร์ตแล้ว')),
      );
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rate(int rating) async {
    setState(() => _busy = true);
    try {
      final data = await _request('manga_rate.php', {
        'manga_id': _manga['manga_id'],
        'rating': rating,
      });
      if (!mounted) return;
      setState(() => _manga = {..._manga, ...data});
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบ Manga'),
        content: Text('ต้องการลบ “${_manga['title']}” หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _request('manga_delete.php', {'manga_id': _manga['manga_id']});
      if (!mounted) return;
      Navigator.pop(context);
    } catch (error) {
      _showError(error);
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(String label, Object? value) {
    final text = (value ?? '').toString().trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(text.isEmpty ? '—' : text),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final readableChapters = _chapters
        .where(
          (chapter) =>
              chapter['content_type'] == 'pdf' ||
              chapter['content_type'] == 'images',
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('รายละเอียด Manga')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: MangaCover(
              manga: _manga,
              accessToken: widget.accessToken,
              width: 190,
              height: 260,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            (_manga['title'] ?? '').toString(),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 20),
          _field('ผู้แต่ง', _manga['author']),
          _field(
            'แนวเรื่อง',
            _manga['genres'] is List
                ? (_manga['genres'] as List).join(', ')
                : _manga['genre'],
          ),
          _field(
            'สถานะ',
            _manga['is_hidden'] == true
                ? 'ถูกซ่อนโดยผู้ดูแล'
                : (_manga['status'] == 'public' ? 'สาธารณะ' : 'ส่วนตัว'),
          ),
          _field('รายละเอียด', _manga['description']),
          _field('สถานะการอัปเดต', mangaReleaseLabel(_manga['release_status'])),
          _field(
            'จำนวนตอน',
            _loadingChapters ? _manga['chapter_count'] : _chapters.length,
          ),
          _field('ผู้อ่าน', _manga['view_count'] ?? 0),
          _field(
            'ความนิยม',
            '★ ${_manga['rating_average'] ?? 0} / 5 (${_manga['rating_count'] ?? 0} คะแนน)',
          ),
          if (!widget.canEdit &&
              _manga['status'] == 'public' &&
              _manga['is_hidden'] != true) ...[
            const Text('ให้คะแนนเรื่องนี้'),
            Wrap(
              children: List.generate(
                5,
                (index) => IconButton(
                  tooltip: '${index + 1} ดาว',
                  onPressed: _busy ? null : () => _rate(index + 1),
                  icon: Icon(
                    (index + 1) <= ((_manga['my_rating'] as num?)?.toInt() ?? 0)
                        ? Icons.star
                        : Icons.star_border,
                  ),
                ),
              ),
            ),
          ],
          if (_manga['username'] != null)
            _field('ผู้เพิ่ม', _manga['username']),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CommentsPage(
                  mangaId: _manga['manga_id'] as int,
                  title: 'ความคิดเห็นของเรื่อง',
                  accessToken: widget.accessToken,
                ),
              ),
            ),
            icon: const Icon(Icons.comment_outlined),
            label: const Text('ความคิดเห็นของเรื่อง'),
          ),
          if (!widget.canEdit &&
              widget.canReport &&
              _manga['status'] == 'public')
            OutlinedButton.icon(
              onPressed: _busy ? null : _report,
              icon: const Icon(Icons.flag_outlined),
              label: const Text('รีพอร์ต Manga'),
            ),
          const SizedBox(height: 12),
          if (_busy) const Center(child: CircularProgressIndicator()),
          if (widget.canEdit) const SizedBox(height: 12),
          if (widget.canEdit)
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : _edit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('แก้ไข'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _delete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('ลบ'),
                ),
              ],
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'ตอน',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (widget.canEdit)
                FilledButton.icon(
                  onPressed: _busy ? null : () => _saveChapter(),
                  icon: const Icon(Icons.add),
                  label: const Text('เพิ่มตอน'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loadingChapters)
            const Center(child: CircularProgressIndicator())
          else if (_chapterError != null)
            TextButton(
              onPressed: _loadChapters,
              child: Text('โหลดตอนไม่สำเร็จ: $_chapterError — ลองอีกครั้ง'),
            )
          else if (_chapters.isEmpty)
            const Text('ยังไม่มีตอน')
          else
            ..._chapters.map((chapter) {
              final canRead =
                  chapter['content_type'] == 'pdf' ||
                  chapter['content_type'] == 'images';
              final label =
                  'ตอนที่ ${chapter['chapter_number']}${(chapter['title'] ?? '').toString().isEmpty ? '' : ' · ${chapter['title']}'}';
              return Card(
                child: ListTile(
                  title: Text(label),
                  subtitle: Text(
                    chapter['is_published'] == true
                        ? 'เผยแพร่แล้ว'
                        : 'ฉบับร่าง',
                  ),
                  onTap: canRead
                      ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MangaReaderPage(
                              mangaId: _manga['manga_id'] as int,
                              chapterId: chapter['chapter_id'] as int,
                              title: label,
                              accessToken: widget.accessToken,
                              chapters: readableChapters,
                              chapterIndex: readableChapters.indexWhere(
                                (item) =>
                                    item['chapter_id'] == chapter['chapter_id'],
                              ),
                            ),
                          ),
                        )
                      : null,
                  trailing: widget.canEdit
                      ? Wrap(
                          spacing: 0,
                          children: [
                            IconButton(
                              tooltip: 'แก้ไขตอน',
                              onPressed: _busy
                                  ? null
                                  : () => _saveChapter(chapter),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'ลบตอน',
                              onPressed: _busy
                                  ? null
                                  : () => _deleteChapter(chapter),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        )
                      : null,
                ),
              );
            }),
        ],
      ),
    );
  }
}

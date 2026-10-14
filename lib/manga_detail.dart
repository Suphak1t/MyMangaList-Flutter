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

/// หน้ารายละเอียดเรื่อง พร้อมตอน คะแนน คอมเมนต์ และการจัดการของเจ้าของ
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
  // สำเนาข้อมูลเรื่องสำหรับอัปเดตจอทันที พร้อมรายการตอนและสถานะกำลังทำงาน
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

  // ตัวช่วย POST JSON ที่แนบ token ตรวจผล success และคืนข้อมูลจาก API
  Future<Map<String, dynamic>> _request(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/$endpoint'),
      headers: { // ส่ง HTTP headers เช่น Bearer token ไปกับคำขอ
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer ${widget.accessToken}',
      },
      body: jsonEncode(body), // แปลงข้อมูลเป็น JSON สำหรับส่งให้ PHP API
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'บันทึกข้อมูลไม่สำเร็จ');
    }
    return data;
  }

  // ขอตอนของเรื่องปัจจุบัน แล้วนำ chapters[] มาแสดงตามสิทธิ์ที่ server ส่ง
  Future<void> _loadChapters() async {
    try {
      final response = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/chapters_get.php?manga_id=${_manga['manga_id']}',
        ),
        headers: {'Authorization': 'Bearer ${widget.accessToken}'}, // ส่ง HTTP headers เช่น Bearer token ไปกับคำขอ
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

  // แปลงข้อผิดพลาดเป็นข้อความสั้นใน SnackBar
  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
    );
  }

  // เปิดฟอร์มพร้อมข้อมูลเดิม บันทึก metadata แล้วอัปโหลดปกใหม่ถ้าเลือก
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

  // โฟลว์เพิ่ม/แก้ตอน: เปิดฟอร์ม → สร้างตอนถ้าจำเป็น → อัปโหลดไฟล์ → เผยแพร่
  Future<void> _saveChapter([Map<String, dynamic>? oldChapter]) async {
    // เสนอเลขตอนถัดจากเลขสูงสุดที่มี ไม่อิงจำนวนแถวอย่างเดียว
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
      // ตอนใหม่ต้องขอ chapter_id ก่อน จึงผูกไฟล์กับตอนนั้นได้
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
      // แก้ชื่อหรือเลขตอนอย่างเดียวได้โดยไม่อัปโหลดไฟล์ซ้ำ
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

  // ถามยืนยันก่อนลบตอน และโหลดรายการตอนใหม่เมื่อสำเร็จ
  Future<void> _deleteChapter(Map<String, dynamic> chapter) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบตอน'),
        content: Text('ต้องการลบตอนที่ ${chapter['chapter_number']} หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), // ปิดหน้าหรือ dialog และส่งผลกลับ
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true), // ปิดหน้าหรือ dialog และส่งผลกลับ
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

  // รับเหตุผลจากผู้อ่านแล้วส่งเรื่องให้คิวรีพอร์ตของ admin
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
            onChanged: (value) => reasonText = value, // ทำงานทันทีเมื่อค่าช่องหรือรายการเลือกเปลี่ยน
            minLines: 3, // จำนวนบรรทัดขั้นต่ำของช่องข้อความ
            maxLines: 5, // จำนวนบรรทัดสูงสุดของช่องข้อความ
            maxLength: 1000, // จำกัดจำนวนตัวอักษรที่พิมพ์ได้
            decoration: const InputDecoration(
              labelText: 'เหตุผลที่ต้องการให้ผู้ดูแลตรวจสอบ', // ข้อความชื่อช่องที่แสดงในฟอร์ม
              border: OutlineInputBorder(),
            ),
            validator: (value) => (value?.trim().length ?? 0) < 10
                ? 'กรุณาระบุเหตุผลอย่างน้อย 10 ตัวอักษร'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext), // ปิดหน้าหรือ dialog และส่งผลกลับ
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () { // เรียก callback นี้เมื่อผู้ใช้กดปุ่ม
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

  // ส่งคะแนนดาวของบัญชีนี้แล้วรวมค่าคะแนนที่ API ตอบกลับเข้าข้อมูลบนจอ
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

  // ถามยืนยันก่อนลบทั้งเรื่อง; PHP เป็นผู้ตรวจสิทธิ์เจ้าของอีกชั้น
  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบ Manga'),
        content: Text('ต้องการลบ “${_manga['title']}” หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), // ปิดหน้าหรือ dialog และส่งผลกลับ
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true), // ปิดหน้าหรือ dialog และส่งผลกลับ
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

  // แถวข้อมูลเรื่องในส่วนคำอธิบายด้านล่าง
  Widget _field(String label, Object? value) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = (value ?? '').toString().trim();
    return Container(
      width: double.infinity, // ความกว้างของพื้นที่แสดงหรือรูปภาพ
      padding: const EdgeInsets.all(20), // ระยะว่างด้านในระหว่างขอบกับเนื้อหา
      decoration: BoxDecoration( // กำหนดสี ขอบ หรือเงาของกล่องนี้
        color: colors.surface,
        borderRadius: BorderRadius.circular(20), // ความโค้งของมุมกรอบ
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // จัดแนวลูกตามแกนขวางของ Row หรือ Column
        children: [
          Text(
            label,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10), // เว้นระยะห่างแนวตั้ง 10 พิกเซล
          Text(
            text.isEmpty ? '—' : text,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }

  // แถวสรุปสั้นข้างภาพปก เช่น ผู้แต่งและสถานะ
  Widget _summaryLine(String label, Object? value) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = (value ?? '').toString().trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10), // ระยะว่างด้านในระหว่างขอบกับเนื้อหา
      child: Text.rich(
        TextSpan(
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            TextSpan(
              text: text.isEmpty ? '—' : text,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  // รวมข้อมูลสรุปที่ใช้ได้ทั้งหน้าจอกว้างและหน้าจอแคบ
  Widget _summaryContent({bool centered = false}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, // จัดแนวลูกตามแกนขวางของ Row หรือ Column
      children: [
        SizedBox(
          width: double.infinity, // ความกว้างของพื้นที่แสดงหรือรูปภาพ
          child: Text(
            (_manga['title'] ?? '').toString(),
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 16), // เว้นระยะห่างแนวตั้ง 16 พิกเซล
        _summaryLine('ผู้แต่ง', _manga['author']),
        _summaryLine(
          'แนวเรื่อง',
          _manga['genres'] is List
              ? (_manga['genres'] as List).join(', ')
              : _manga['genre'],
        ),
        _summaryLine(
          'Visibility',
          _manga['is_hidden'] == true
              ? 'Hidden by admin'
              : mangaVisibilityLabel(_manga['status']),
        ),
        _summaryLine(
          'Release status',
          mangaReleaseLabel(_manga['release_status']),
        ),
        _summaryLine(
          'จำนวนตอน',
          _loadingChapters ? _manga['chapter_count'] : _chapters.length,
        ),
        _summaryLine('ผู้อ่าน', _manga['view_count'] ?? 0),
        _summaryLine(
          'ความนิยม',
          '★ ${_manga['rating_average'] ?? 0} / 5 (${_manga['rating_count'] ?? 0} คะแนน)',
        ),
        if (_manga['username'] != null)
          _summaryLine('ผู้เพิ่ม', _manga['username']),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // เก็บเฉพาะตอนที่มีไฟล์อ่านได้ไว้ใช้คำนวณตำแหน่งตอนก่อนหน้า/ตอนถัดไป
    final readableChapters = _chapters
        .where(
          (chapter) =>
              chapter['content_type'] == 'pdf' ||
              chapter['content_type'] == 'images',
        )
        .toList();
    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text(
          'รายละเอียด Manga',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: colors.surface,
        scrolledUnderElevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => ListView(
          padding: EdgeInsets.fromLTRB( // ระยะว่างด้านในระหว่างขอบกับเนื้อหา
            ((constraints.maxWidth - 920) / 2).clamp(20.0, double.infinity),
            24,
            ((constraints.maxWidth - 920) / 2).clamp(20.0, double.infinity),
            48,
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(20), // ระยะว่างด้านในระหว่างขอบกับเนื้อหา
              decoration: BoxDecoration( // กำหนดสี ขอบ หรือเงาของกล่องนี้
                color: colors.surface,
                borderRadius: BorderRadius.circular(24), // ความโค้งของมุมกรอบ
                border: Border.all(color: colors.outlineVariant),
              ),
              child: LayoutBuilder(
                builder: (context, cardConstraints) {
                  // จอแคบวางปกเหนือข้อมูล; จอกว้างวางข้อมูลข้างปก
                  if (cardConstraints.maxWidth < 520) {
                    return Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14), // ความโค้งของมุมกรอบ
                          child: MangaCover(
                            manga: _manga,
                            accessToken: widget.accessToken,
                            width: 136, // ความกว้างของพื้นที่แสดงหรือรูปภาพ
                            height: 186, // ความสูงของพื้นที่แสดงหรือรูปภาพ
                          ),
                        ),
                        const SizedBox(height: 20), // เว้นระยะห่างแนวตั้ง 20 พิกเซล
                        _summaryContent(centered: true),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start, // จัดแนวลูกตามแกนขวางของ Row หรือ Column
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14), // ความโค้งของมุมกรอบ
                        child: MangaCover(
                          manga: _manga,
                          accessToken: widget.accessToken,
                          width: 190, // ความกว้างของพื้นที่แสดงหรือรูปภาพ
                          height: 260, // ความสูงของพื้นที่แสดงหรือรูปภาพ
                        ),
                      ),
                      const SizedBox(width: 24), // เว้นระยะห่างแนวนอน 24 พิกเซล
                      Expanded(child: _summaryContent()),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 20), // เว้นระยะห่างแนวตั้ง 20 พิกเซล
            _field('รายละเอียด', _manga['description']),
            // ผู้อ่านให้ดาวได้เฉพาะเรื่องสาธารณะที่ไม่ถูกซ่อน
            if (!widget.canEdit &&
                _manga['status'] == 'public' &&
                _manga['is_hidden'] != true) ...[
              const SizedBox(height: 16), // เว้นระยะห่างแนวตั้ง 16 พิกเซล
              Container(
                width: double.infinity, // ความกว้างของพื้นที่แสดงหรือรูปภาพ
                padding: const EdgeInsets.all(20), // ระยะว่างด้านในระหว่างขอบกับเนื้อหา
                decoration: BoxDecoration( // กำหนดสี ขอบ หรือเงาของกล่องนี้
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(20), // ความโค้งของมุมกรอบ
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, // จัดแนวลูกตามแกนขวางของ Row หรือ Column
                  children: [
                    Text(
                      'ให้คะแนนเรื่องนี้',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8), // เว้นระยะห่างแนวตั้ง 8 พิกเซล
                    Wrap(
                      children: List.generate(
                        5,
                        (index) => IconButton(
                          tooltip: '${index + 1} ดาว',
                          onPressed: _busy ? null : () => _rate(index + 1), // ปิดปุ่มชั่วคราวเมื่อยังไม่พร้อม แล้วเรียกคำสั่งเมื่อกดได้
                          color: colors.primary,
                          icon: Icon(
                            (index + 1) <=
                                    ((_manga['my_rating'] as num?)?.toInt() ??
                                        0)
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16), // เว้นระยะห่างแนวตั้ง 16 พิกเซล
            OutlinedButton.icon(
              onPressed: () => Navigator.push( // เปิดหน้าใหม่เมื่อกดปุ่ม
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
            // แสดงปุ่มรีพอร์ตเมื่อหน้าที่เปิดอนุญาตและเรื่องเป็นสาธารณะ
            if (!widget.canEdit &&
                widget.canReport &&
                _manga['status'] == 'public') ...[
              const SizedBox(height: 8), // เว้นระยะห่างแนวตั้ง 8 พิกเซล
              OutlinedButton.icon(
                onPressed: _busy ? null : _report, // ปิดปุ่มชั่วคราวเมื่อยังไม่พร้อม แล้วเรียกคำสั่งเมื่อกดได้
                icon: const Icon(Icons.flag_outlined),
                label: const Text('รีพอร์ต Manga'),
              ),
            ],
            const SizedBox(height: 12), // เว้นระยะห่างแนวตั้ง 12 พิกเซล
            if (_busy) const Center(child: CircularProgressIndicator()),
            if (widget.canEdit) const SizedBox(height: 12), // เว้นระยะห่างแนวตั้ง 12 พิกเซล
            // ปุ่มแก้ไขและลบเรื่องมีเฉพาะฝั่งเจ้าของใน UI
            if (widget.canEdit)
              Wrap(
                spacing: 12, // ระยะห่างระหว่าง widget ที่อยู่บรรทัดเดียวกัน
                runSpacing: 8, // ระยะห่างระหว่างบรรทัดเมื่อ Wrap ขึ้นบรรทัดใหม่
                children: [
                  FilledButton.icon(
                    onPressed: _busy ? null : _edit, // ปิดปุ่มชั่วคราวเมื่อยังไม่พร้อม แล้วเรียกคำสั่งเมื่อกดได้
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('แก้ไข'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _delete, // ปิดปุ่มชั่วคราวเมื่อยังไม่พร้อม แล้วเรียกคำสั่งเมื่อกดได้
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('ลบ'),
                  ),
                ],
              ),
            const SizedBox(height: 24), // เว้นระยะห่างแนวตั้ง 24 พิกเซล
            Row(
              children: [
                Expanded(
                  child: Text(
                    'ตอน',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (widget.canEdit)
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _saveChapter(), // ปิดปุ่มชั่วคราวเมื่อยังไม่พร้อม แล้วเรียกคำสั่งเมื่อกดได้
                    icon: const Icon(Icons.add),
                    label: const Text('เพิ่มตอน'),
                  ),
              ],
            ),
            const SizedBox(height: 12), // เว้นระยะห่างแนวตั้ง 12 พิกเซล
            // พื้นที่รายการตอนแยกสถานะโหลด ผิดพลาด ว่าง และมีข้อมูล
            if (_loadingChapters)
              const Padding(
                padding: EdgeInsets.all(36), // ระยะว่างด้านในระหว่างขอบกับเนื้อหา
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_chapterError != null)
              _ChapterMessage(
                icon: Icons.cloud_off_outlined,
                title: 'โหลดตอนไม่สำเร็จ',
                message: _chapterError!,
                onRetry: _loadChapters,
              )
            else if (_chapters.isEmpty)
              const _ChapterMessage(
                icon: Icons.menu_book_outlined,
                title: 'ยังไม่มีตอน',
                message: 'ตอนของเรื่องจะแสดงที่นี่',
              )
            else
              ..._chapters.map((chapter) {
                // ตอนที่ยังไม่มีไฟล์แสดงได้ แต่กดเปิดหน้าอ่านไม่ได้
                final canRead =
                    chapter['content_type'] == 'pdf' ||
                    chapter['content_type'] == 'images';
                final label =
                    'ตอนที่ ${chapter['chapter_number']}${(chapter['title'] ?? '').toString().isEmpty ? '' : ' · ${chapter['title']}'}';
                return Card(
                  margin: const EdgeInsets.only(bottom: 10), // ระยะว่างด้านนอกระหว่าง widget กับบริเวณรอบข้าง
                  color: colors.surface,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16), // ความโค้งของมุมกรอบ
                    side: BorderSide(color: colors.outlineVariant),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric( // ระยะว่างภายในส่วนเนื้อหาของ widget
                      horizontal: 18,
                      vertical: 6,
                    ),
                    title: Text(
                      label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      chapter['is_published'] == true
                          ? 'เผยแพร่แล้ว'
                          : 'ฉบับร่าง',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
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
                                      item['chapter_id'] ==
                                      chapter['chapter_id'],
                                ),
                              ),
                            ),
                          )
                        : null,
                    trailing: widget.canEdit
                        ? Wrap(
                            spacing: 0, // ระยะห่างระหว่าง widget ที่อยู่บรรทัดเดียวกัน
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
      ),
    );
  }
}

/// ข้อความแทนรายการตอนเมื่อไม่มีตอนหรือโหลดผิดพลาด
class _ChapterMessage extends StatelessWidget {
  const _ChapterMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      width: double.infinity, // ความกว้างของพื้นที่แสดงหรือรูปภาพ
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40), // ระยะว่างด้านในระหว่างขอบกับเนื้อหา
      decoration: BoxDecoration( // กำหนดสี ขอบ หรือเงาของกล่องนี้
        color: colors.surface,
        borderRadius: BorderRadius.circular(20), // ความโค้งของมุมกรอบ
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, size: 44, color: colors.primary),
          const SizedBox(height: 16), // เว้นระยะห่างแนวตั้ง 16 พิกเซล
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6), // เว้นระยะห่างแนวตั้ง 6 พิกเซล
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 18), // เว้นระยะห่างแนวตั้ง 18 พิกเซล
            OutlinedButton(
              onPressed: onRetry, // เรียก callback นี้เมื่อผู้ใช้กดปุ่ม
              child: const Text('ลองอีกครั้ง'),
            ),
          ],
        ],
      ),
    );
  }
}

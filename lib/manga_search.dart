import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'config.dart';
import 'genre_options.dart';
import 'manga_card.dart';
import 'manga_detail.dart';

/// หน้าค้นหา Manga พร้อมตัวกรองข้อความ แนวเรื่อง และสถานะ
class MangaSearchPage extends StatefulWidget {
  const MangaSearchPage({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<MangaSearchPage> createState() => _MangaSearchPageState();
}

class _MangaSearchPageState extends State<MangaSearchPage> {
  // State เก็บคำค้น รายการที่ได้จาก API และค่าของตัวกรองทั้งหมด
  final _query = TextEditingController();
  List<Map<String, dynamic>> _manga = [];
  bool _public = true;
  bool _loading = true;
  String? _error;
  final Set<String> _selectedGenres = {};
  String _release = 'all';
  String _visibility = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  // โหลดเฉพาะรายการที่บัญชีนี้มีสิทธิ์เห็นจาก manga_get.php
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}/manga_get.php${_public ? '?scope=public' : ''}',
      );
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer ${widget.user['access_token']}'}, // ส่ง HTTP headers เช่น Bearer token ไปกับคำขอ
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || data['success'] != true) {
        throw Exception(data['message'] ?? 'ค้นหา Manga ไม่สำเร็จ');
      }
      if (!mounted) return;
      setState(() {
        _manga = (data['manga'] as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // กรองรายการในหน่วยความจำหลัง server คัดขอบเขตข้อมูลแล้ว
  List<Map<String, dynamic>> get _results {
    final text = _query.text.trim().toLowerCase();
    return _manga.where((manga) {
      final genres = manga['genres'] is List
          ? manga['genres'] as List
          : [manga['genre']];
      // รวมชื่อเรื่อง ผู้แต่ง และแนวไว้เป็นข้อความเดียวสำหรับค้นหา
      final haystack = [
        manga['title'],
        manga['author'],
        ...genres,
      ].whereType<String>().join(' ').toLowerCase();
      return (text.isEmpty || haystack.contains(text)) &&
          // ถ้าติ๊กหลายแนว ให้ผ่านเมื่อ Manga ตรงอย่างน้อยหนึ่งแนว
          (_selectedGenres.isEmpty ||
              genres.any((genre) => _selectedGenres.contains(genre))) &&
          (_release == 'all' || manga['release_status'] == _release) &&
          (_public || _visibility == 'all' || manga['status'] == _visibility);
    }).toList();
  }

  // เปิดรายละเอียด พร้อมบอก UI ว่าบัญชีนี้เป็นเจ้าของเรื่องหรือไม่
  Future<void> _open(Map<String, dynamic> manga) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => MangaDetailPage(
          manga: manga,
          accessToken: widget.user['access_token'].toString(),
          canEdit: manga['user_id'] == widget.user['user_id'],
        ),
      ),
    );
    if (mounted) _load();
  }

  // แสดง checklist จากรายการแนวทั้งหมด พร้อมค้นหาภายในกล่องเลือก
  Future<void> _chooseGenres() async {
    String query = '';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateDialog) {
          final filtered = mangaGenres
              .where(
                (genre) => genre.toLowerCase().contains(query.toLowerCase()),
              )
              .toList();
          return AlertDialog(
            title: const Text('เลือกประเภทการ์ตูน'),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24), // ความโค้งของมุมกรอบ
            ),
            content: SizedBox(
              width: 400, // ความกว้างของพื้นที่แสดงหรือรูปภาพ
              height: 430, // ความสูงของพื้นที่แสดงหรือรูปภาพ
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration( // กำหนดข้อความและรูปแบบขอบของช่องกรอก
                      hintText: 'ค้นหาแนวเรื่อง', // ข้อความตัวอย่างก่อนผู้ใช้พิมพ์
                      prefixIcon: const Icon(Icons.search_rounded), // ไอคอนด้านหน้าของช่องกรอก
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), // ความโค้งของมุมกรอบ
                      ),
                    ),
                    onChanged: (value) => updateDialog(() => query = value), // ทำงานทันทีเมื่อค่าช่องหรือรายการเลือกเปลี่ยน
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length, // จำนวนรายการที่ ListView หรือ PageView ต้องสร้าง
                      itemBuilder: (context, index) { // สร้าง widget ของแต่ละรายการตาม index
                        final genre = filtered[index];
                        return CheckboxListTile(
                          title: Text(genre),
                          value: _selectedGenres.contains(genre), // ติ๊กถูกเมื่อแนวนี้อยู่ในตัวกรอง
                          onChanged: (checked) { // ทำงานทันทีเมื่อค่าช่องหรือรายการเลือกเปลี่ยน
                            updateDialog(() {
                              if (checked == true) {
                                _selectedGenres.add(genre);
                              } else {
                                _selectedGenres.remove(genre);
                              }
                            });
                            setState(() {});
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () { // เรียก callback นี้เมื่อผู้ใช้กดปุ่ม
                  updateDialog(_selectedGenres.clear);
                  setState(() {});
                },
                child: const Text('ล้างที่เลือก'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext), // ปิดหน้าหรือ dialog และส่งผลกลับ
                child: const Text('เสร็จ'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final results = _results;
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12), // ความโค้งของมุมกรอบ
    );

    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text(
          'ค้นหา Manga',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: colors.surface,
        scrolledUnderElevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: EdgeInsets.fromLTRB( // ระยะว่างด้านในระหว่างขอบกับเนื้อหา
              ((constraints.maxWidth - 760) / 2).clamp(20.0, double.infinity),
              24,
              ((constraints.maxWidth - 760) / 2).clamp(20.0, double.infinity),
              40,
            ),
            children: [
              Container(
                padding: const EdgeInsets.all(24), // ระยะว่างด้านในระหว่างขอบกับเนื้อหา
                decoration: BoxDecoration( // กำหนดสี ขอบ หรือเงาของกล่องนี้
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.primaryContainer,
                      colors.secondaryContainer,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24), // ความโค้งของมุมกรอบ
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, // จัดแนวลูกตามแกนขวางของ Row หรือ Column
                        children: [
                          Text(
                            'ค้นหาเรื่องที่คุณชอบ',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colors.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 8), // เว้นระยะห่างแนวตั้ง 8 พิกเซล
                          Text(
                            'เลือกแนวเรื่องและสถานะเพื่อค้นหา Manga',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12), // เว้นระยะห่างแนวนอน 12 พิกเซล
                    Icon(
                      Icons.travel_explore_rounded,
                      size: 44,
                      color: colors.onPrimaryContainer.withValues(alpha: 0.72),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24), // เว้นระยะห่างแนวตั้ง 24 พิกเซล
              Container(
                padding: const EdgeInsets.all(18), // ระยะว่างด้านในระหว่างขอบกับเนื้อหา
                decoration: BoxDecoration( // กำหนดสี ขอบ หรือเงาของกล่องนี้
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(20), // ความโค้งของมุมกรอบ
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch, // จัดแนวลูกตามแกนขวางของ Row หรือ Column
                  children: [
                    Text(
                      'ตัวกรองการค้นหา',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16), // เว้นระยะห่างแนวตั้ง 16 พิกเซล
                    TextField(
                      controller: _query, // เก็บข้อความค้นหาที่ผู้ใช้พิมพ์
                      onChanged: (_) => setState(() {}), // ทำงานทันทีเมื่อค่าช่องหรือรายการเลือกเปลี่ยน
                      decoration: InputDecoration( // กำหนดข้อความและรูปแบบขอบของช่องกรอก
                        labelText: 'ชื่อเรื่อง ผู้แต่ง หรือแนวเรื่อง', // ข้อความชื่อช่องที่แสดงในฟอร์ม
                        prefixIcon: const Icon(Icons.search_rounded), // ไอคอนด้านหน้าของช่องกรอก
                        border: fieldBorder,
                      ),
                    ),
                    const SizedBox(height: 12), // เว้นระยะห่างแนวตั้ง 12 พิกเซล
                    // เลือกว่าจะขอรายการสาธารณะหรือรายการของบัญชีนี้
                    Wrap(
                      spacing: 10, // ระยะห่างระหว่าง widget ที่อยู่บรรทัดเดียวกัน
                      runSpacing: 8, // ระยะห่างระหว่างบรรทัดเมื่อ Wrap ขึ้นบรรทัดใหม่
                      children: [
                        ChoiceChip(
                          avatar: const Icon(Icons.public_rounded, size: 18),
                          label: const Text('สาธารณะ'),
                          selected: _public, // กำหนดว่าชิปนี้อยู่ในสถานะเลือกหรือไม่
                          onSelected: (_) { // ทำงานเมื่อเลือกชิปนี้
                            setState(() => _public = true);
                            _load();
                          },
                        ),
                        ChoiceChip(
                          avatar: const Icon(
                            Icons.bookmark_outline_rounded,
                            size: 18,
                          ),
                          label: const Text('ของฉัน'),
                          selected: !_public, // กำหนดว่าชิปนี้อยู่ในสถานะเลือกหรือไม่
                          onSelected: (_) { // ทำงานเมื่อเลือกชิปนี้
                            setState(() => _public = false);
                            _load();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12), // เว้นระยะห่างแนวตั้ง 12 พิกเซล
                    OutlinedButton.icon(
                      onPressed: _chooseGenres, // เรียก callback นี้เมื่อผู้ใช้กดปุ่ม
                      icon: const Icon(Icons.category_outlined),
                      label: Text(
                        _selectedGenres.isEmpty
                            ? 'ประเภทการ์ตูน: ทุกแนว'
                            : 'ประเภทการ์ตูน: เลือก ${_selectedGenres.length} แนว',
                      ),
                    ),
                    // ชิปแต่ละแนวลบตัวกรองนั้นได้โดยไม่เปิด checklist ซ้ำ
                    if (_selectedGenres.isNotEmpty) ...[
                      const SizedBox(height: 8), // เว้นระยะห่างแนวตั้ง 8 พิกเซล
                      Wrap(
                        spacing: 6, // ระยะห่างระหว่าง widget ที่อยู่บรรทัดเดียวกัน
                        runSpacing: 4, // ระยะห่างระหว่างบรรทัดเมื่อ Wrap ขึ้นบรรทัดใหม่
                        children: _selectedGenres
                            .map(
                              (genre) => InputChip(
                                label: Text(genre),
                                onDeleted: () => setState( // ลบชิปตัวกรองนี้เมื่อกดเครื่องหมายปิด
                                  () => _selectedGenres.remove(genre),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 12), // เว้นระยะห่างแนวตั้ง 12 พิกเซล
                    DropdownButtonFormField<String>(
                      value: _release, // สถานะการออกตอนที่กำลังใช้กรอง
                      decoration: InputDecoration( // กำหนดข้อความและรูปแบบขอบของช่องกรอก
                        labelText: 'Release status', // ข้อความชื่อช่องที่แสดงในฟอร์ม
                        prefixIcon: const Icon(Icons.schedule_rounded), // ไอคอนด้านหน้าของช่องกรอก
                        border: fieldBorder,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All')),
                        DropdownMenuItem(
                          value: 'coming_soon', // รหัสตัวกรอง Coming Soon
                          child: Text('Coming Soon'),
                        ),
                        DropdownMenuItem(
                          value: 'ongoing', // รหัสตัวกรอง Ongoing
                          child: Text('Ongoing'),
                        ),
                        DropdownMenuItem(
                          value: 'hiatus', // รหัสตัวกรอง Hiatus
                          child: Text('Hiatus'),
                        ),
                        DropdownMenuItem(
                          value: 'completed', // รหัสตัวกรอง Completed
                          child: Text('Completed'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _release = value ?? 'all'),
                    ),
                    // ตัวกรอง Private/Public มีความหมายเฉพาะรายการของฉัน
                    if (!_public) ...[
                      const SizedBox(height: 12), // เว้นระยะห่างแนวตั้ง 12 พิกเซล
                      DropdownButtonFormField<String>(
                        value: _visibility, // ค่า Private/Public ที่กำลังใช้กรอง
                        decoration: InputDecoration( // กำหนดข้อความและรูปแบบขอบของช่องกรอก
                          labelText: 'Visibility', // ข้อความชื่อช่องที่แสดงในฟอร์ม
                          prefixIcon: const Icon(Icons.filter_list_rounded), // ไอคอนด้านหน้าของช่องกรอก
                          border: fieldBorder,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All')),
                          DropdownMenuItem(
                            value: 'private', // รหัสตัวเลือกเฉพาะเรื่องส่วนตัว
                            child: Text('Private'),
                          ),
                          DropdownMenuItem(
                            value: 'public', // รหัสตัวเลือกเฉพาะเรื่องสาธารณะ
                            child: Text('Public'),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _visibility = value ?? 'all'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 28), // เว้นระยะห่างแนวตั้ง 28 พิกเซล
              // พื้นที่ผลลัพธ์แยกโหลด ผิดพลาด ไม่พบ และพบ Manga
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(36), // ระยะว่างด้านในระหว่างขอบกับเนื้อหา
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _SearchMessage(
                  icon: Icons.cloud_off_outlined,
                  title: 'ค้นหาไม่สำเร็จ',
                  message: _error!,
                  onRetry: _load,
                )
              else if (results.isEmpty)
                const _SearchMessage(
                  icon: Icons.search_off_rounded,
                  title: 'ไม่พบ Manga',
                  message: 'ลองเปลี่ยนคำค้นหาหรือตัวกรอง',
                )
              else ...[
                Text(
                  'ผลการค้นหา · พบ ${results.length} เรื่อง',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12), // เว้นระยะห่างแนวตั้ง 12 พิกเซล
                ...results.map(
                  (manga) => MangaCard(
                    manga: manga,
                    accessToken: widget.user['access_token'].toString(),
                    onTap: () => _open(manga), // ทำงานเมื่อแตะการ์ดหรือรายการนี้
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// ข้อความประกอบสถานะไม่มีผลลัพธ์หรือโหลดข้อมูลไม่สำเร็จ
class _SearchMessage extends StatelessWidget {
  const _SearchMessage({
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
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(20), // ความโค้งของมุมกรอบ
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

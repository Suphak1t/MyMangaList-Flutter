import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'add_manga_dialog.dart';
import 'admin_dashboard.dart';
import 'config.dart';
import 'manga_card.dart';
import 'manga_cover.dart';
import 'manga_detail.dart';
import 'manga_search.dart';
import 'theme_mode.dart';

/// หน้าหลักรับข้อมูลบัญชีและ token จาก Login พร้อมปุ่มออกจากระบบ
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.user, this.onLogout});

  final Map<String, dynamic> user;
  final VoidCallback? onLogout;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // ค่าที่ใช้กรองความเป็นส่วนตัวของ Manga ในแท็บของฉัน
  static const _statuses = ['private', 'public'];

  // State แยกรายการที่แสดง รายการ Top 10 ตัวกรอง และสถานะการโหลด
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _manga = [];
  List<Map<String, dynamic>> _topManga = [];
  String _selectedStatus = 'All';
  bool _showPublic = false;
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadManga();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ขอรายการตามแท็บและรายการสาธารณะ แล้วปรับ State ให้การ์ดแสดงข้อมูลใหม่
  Future<void> _loadManga() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final headers = {
        'Authorization': 'Bearer ${widget.user['access_token']}',
      };
      // ขอสองรายการพร้อมกัน: รายการของแท็บปัจจุบันและรายการสำหรับ Top 10
      final responses = await Future.wait([
        http.get(
          Uri.parse(
            '${ApiConfig.baseUrl}/manga_get.php${_showPublic ? '?scope=public' : ''}',
          ),
          headers: headers, // ส่ง HTTP headers เช่น Bearer token ไปกับคำขอ
        ),
        http.get(
          Uri.parse('${ApiConfig.baseUrl}/manga_get.php?scope=public'),
          headers: headers, // ส่ง HTTP headers เช่น Bearer token ไปกับคำขอ
        ),
      ]);
      final data = jsonDecode(responses[0].body) as Map<String, dynamic>;
      final publicData = jsonDecode(responses[1].body) as Map<String, dynamic>;
      if (responses[0].statusCode != 200 ||
          data['success'] != true ||
          responses[1].statusCode != 200 ||
          publicData['success'] != true) {
        throw Exception(data['message'] ?? 'โหลดรายการ Manga ไม่สำเร็จ');
      }
      final items = data['manga'] as List<dynamic>? ?? [];
      final top = (publicData['manga'] as List<dynamic>? ?? [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      // จัด Top 10 ตามยอดชมก่อน; คะแนนเฉลี่ยใช้ตัดสินเมื่อยอดชมเท่ากัน
      top.sort((a, b) {
        final views = (b['view_count'] as num).compareTo(
          a['view_count'] as num,
        );
        return views != 0
            ? views
            : (b['rating_average'] as num).compareTo(
                a['rating_average'] as num,
              );
      });
      if (!mounted) return;
      setState(() {
        _manga = items
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        _topManga = top.take(10).toList();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // เปิดฟอร์มเพิ่มเรื่อง ส่ง metadata ก่อน แล้วค่อยอัปโหลดภาพปกถ้ามี
  Future<void> _addManga() async {
    final manga = await showDialog<MangaFormResult>(
      context: context,
      builder: (context) => const AddMangaDialog(),
    );
    if (manga == null) return;

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/manga_add.php'),
        headers: { // ส่ง HTTP headers เช่น Bearer token ไปกับคำขอ
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer ${widget.user['access_token']}',
        },
        body: jsonEncode(manga.fields), // แปลงข้อมูลเป็น JSON สำหรับส่งให้ PHP API
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200 || data['success'] != true) {
        throw Exception(data['message'] ?? 'เพิ่ม Manga ไม่สำเร็จ');
      }

      // ภาพปกเป็นคำขอแยกจากการสร้าง Manga; หากพลาด เรื่องยังถูกสร้างแล้ว
      if (manga.coverFile != null) {
        try {
          await uploadMangaCover(
            (data['manga_id'] as num).toInt(),
            manga.coverFile!,
            widget.user['access_token'].toString(),
          );
        } catch (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('สร้างเรื่องแล้ว แต่ภาพปกไม่สำเร็จ: $error'),
              ),
            );
          }
        }
      }

      if (mounted) setState(() => _showPublic = false);
      await _loadManga();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message'] ?? 'เพิ่ม Manga สำเร็จ')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  // กรองรายการที่ API ส่งมาแล้วตามสถานะและข้อความค้นหาของแท็บของฉัน
  List<Map<String, dynamic>> get _visibleManga {
    final query = _showPublic
        ? ''
        : _searchController.text.trim().toLowerCase();
    return _manga.where((item) {
      final matchesStatus =
          _selectedStatus == 'All' || item['status'] == _selectedStatus;
      final searchable = [
        item['title'],
        item['author'],
        item['genre'],
        if (item['genres'] is List) ...(item['genres'] as List),
      ].whereType<String>().join(' ').toLowerCase();
      return matchesStatus && (query.isEmpty || searchable.contains(query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isAdmin = (widget.user['role'] ?? '').toString() == 'admin';
    final publicCount = _manga
        .where(
          (item) => item['status'] == 'public' && item['is_hidden'] != true,
        )
        .length;

    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text(
          'MyMangaList',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: colors.surface,
        scrolledUnderElevation: 0,
        actions: [
          // ปุ่มค้นหาแยกมีเฉพาะแท็บสาธารณะ
          if (_showPublic)
            IconButton(
              tooltip: 'ค้นหา Manga',
              onPressed: () => Navigator.push( // เปิดหน้าใหม่เมื่อกดปุ่ม
                context,
                MaterialPageRoute(
                  builder: (context) => MangaSearchPage(user: widget.user),
                ),
              ),
              icon: const Icon(Icons.search),
            ),
          IconButton(
            tooltip: 'สลับธีมมืด',
            onPressed: toggleAppTheme, // เรียก callback นี้เมื่อผู้ใช้กดปุ่ม
            icon: const Icon(Icons.dark_mode_outlined),
          ),
          // การเห็นปุ่ม Admin เป็นเพียง UI; API ตรวจ role อีกครั้ง
          if (isAdmin)
            IconButton(
              tooltip: 'จัดการผู้ใช้',
              onPressed: () => Navigator.push( // เปิดหน้าใหม่เมื่อกดปุ่ม
                context,
                MaterialPageRoute(
                  builder: (context) => AdminDashboardPage(user: widget.user),
                ),
              ),
              icon: const Icon(Icons.admin_panel_settings_outlined),
            ),
          IconButton(
            tooltip: 'ออกจากระบบ',
            onPressed: widget.onLogout, // เรียก callback นี้เมื่อผู้ใช้กดปุ่ม
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addManga, // เรียก callback นี้เมื่อผู้ใช้กดปุ่ม
        icon: const Icon(Icons.add_rounded),
        label: const Text('เพิ่ม Manga'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => RefreshIndicator(
          onRefresh: _loadManga,
          child: ListView(
            padding: EdgeInsets.fromLTRB( // ระยะว่างด้านในระหว่างขอบกับเนื้อหา
              ((constraints.maxWidth - 920) / 2).clamp(20.0, double.infinity),
              24,
              ((constraints.maxWidth - 920) / 2).clamp(20.0, double.infinity),
              112,
            ),
            children: [
              _DashboardHeader(
                username: (widget.user['username'] ?? 'นักอ่าน').toString(),
                showPublic: _showPublic,
              ),
              const SizedBox(height: 24), // เว้นระยะห่างแนวตั้ง 24 พิกเซล
              Row(
                children: [
                  Text(
                    'สำรวจชั้นหนังสือ',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12), // เว้นระยะห่างแนวตั้ง 12 พิกเซล
              // ชิปสองตัวสลับขอบเขตข้อมูลแล้วโหลดรายการจาก API ใหม่
              Wrap(
                spacing: 10, // ระยะห่างระหว่าง widget ที่อยู่บรรทัดเดียวกัน
                runSpacing: 8, // ระยะห่างระหว่างบรรทัดเมื่อ Wrap ขึ้นบรรทัดใหม่
                children: [
                  ChoiceChip(
                    avatar: const Icon(
                      Icons.bookmark_outline_rounded,
                      size: 18,
                    ),
                    label: const Text('ของฉัน'),
                    selected: !_showPublic, // กำหนดว่าชิปนี้อยู่ในสถานะเลือกหรือไม่
                    onSelected: (_) { // ทำงานเมื่อเลือกชิปนี้
                      setState(() {
                        _showPublic = false;
                        _selectedStatus = 'All';
                      });
                      _loadManga();
                    },
                  ),
                  ChoiceChip(
                    avatar: const Icon(Icons.public_rounded, size: 18),
                    label: const Text('สาธารณะ'),
                    selected: _showPublic, // กำหนดว่าชิปนี้อยู่ในสถานะเลือกหรือไม่
                    onSelected: (_) { // ทำงานเมื่อเลือกชิปนี้
                      setState(() {
                        _showPublic = true;
                        _selectedStatus = 'All';
                      });
                      _loadManga();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20), // เว้นระยะห่างแนวตั้ง 20 พิกเซล
              Row(
                children: [
                  Expanded(
                    child: _SummaryTile(
                      label: 'ทั้งหมด',
                      value: '${_manga.length}', // แสดงจำนวน Manga ทั้งหมดในแท็บปัจจุบัน
                      icon: Icons.auto_stories_outlined,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: 12), // เว้นระยะห่างแนวนอน 12 พิกเซล
                  Expanded(
                    child: _SummaryTile(
                      label: 'สาธารณะ',
                      value: '$publicCount', // แสดงจำนวนเรื่องสาธารณะที่นับได้
                      icon: Icons.menu_book_outlined,
                      color: colors.tertiary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28), // เว้นระยะห่างแนวตั้ง 28 พิกเซล
              if (_showPublic) ...[
                SizedBox(
                  width: double.infinity, // ความกว้างของพื้นที่แสดงหรือรูปภาพ
                  child: FilledButton.icon(
                    onPressed: () => Navigator.push( // เปิดหน้าใหม่เมื่อกดปุ่ม
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            MangaSearchPage(user: widget.user),
                      ),
                    ),
                    icon: const Icon(Icons.search_rounded),
                    label: const Text('ไปหน้าค้นหาและกรอง Manga'),
                  ),
                ),
                const SizedBox(height: 28), // เว้นระยะห่างแนวตั้ง 28 พิกเซล
              ],
              // Top 10 ใช้รายการสาธารณะที่ _loadManga เรียงไว้แล้ว
              if (_showPublic && _topManga.isNotEmpty) ...[
                Text(
                  'Top 10 ยอดผู้อ่าน',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12), // เว้นระยะห่างแนวตั้ง 12 พิกเซล
                ..._topManga.asMap().entries.map(
                  (entry) => Row(
                    children: [
                      Container(
                        width: 34, // ความกว้างของพื้นที่แสดงหรือรูปภาพ
                        height: 34, // ความสูงของพื้นที่แสดงหรือรูปภาพ
                        alignment: Alignment.center, // ตำแหน่งวางเนื้อหาภายในพื้นที่ของ widget
                        margin: const EdgeInsets.only(right: 10), // ระยะว่างด้านนอกระหว่าง widget กับบริเวณรอบข้าง
                        decoration: BoxDecoration( // กำหนดสี ขอบ หรือเงาของกล่องนี้
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(10), // ความโค้งของมุมกรอบ
                        ),
                        child: Text(
                          '${entry.key + 1}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colors.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: MangaCard(
                          manga: entry.value,
                          accessToken: widget.user['access_token'].toString(),
                          onTap: () => _openManga(entry.value), // ทำงานเมื่อแตะการ์ดหรือรายการนี้
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24), // เว้นระยะห่างแนวตั้ง 24 พิกเซล
              ],
              // ช่องค้นหาและตัวกรอง Visibility ภายในหน้ามีเฉพาะของฉัน
              if (!_showPublic) ...[
                Text(
                  'ค้นหาและกรองรายการ',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12), // เว้นระยะห่างแนวตั้ง 12 พิกเซล
                Container(
                  padding: const EdgeInsets.all(16), // ระยะว่างด้านในระหว่างขอบกับเนื้อหา
                  decoration: BoxDecoration( // กำหนดสี ขอบ หรือเงาของกล่องนี้
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(20), // ความโค้งของมุมกรอบ
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController, // ผูกช่องค้นหากับข้อความที่ใช้กรองรายการ
                        onChanged: (_) => setState(() {}), // ทำงานทันทีเมื่อค่าช่องหรือรายการเลือกเปลี่ยน
                        decoration: InputDecoration( // กำหนดข้อความและรูปแบบขอบของช่องกรอก
                          hintText: 'ค้นหาชื่อเรื่อง ผู้แต่ง หรือแนว', // ข้อความตัวอย่างก่อนผู้ใช้พิมพ์
                          prefixIcon: const Icon(Icons.search_rounded), // ไอคอนด้านหน้าของช่องกรอก
                          suffixIcon: _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'ล้างคำค้นหา',
                                  onPressed: () { // เรียก callback นี้เมื่อผู้ใช้กดปุ่ม
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.close),
                                ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12), // ความโค้งของมุมกรอบ
                          ),
                        ),
                      ),
                      const SizedBox(height: 12), // เว้นระยะห่างแนวตั้ง 12 พิกเซล
                      DropdownButtonFormField<String>(
                        value: _selectedStatus, // ค่า Visibility ที่เลือกกรองอยู่
                        decoration: InputDecoration( // กำหนดข้อความและรูปแบบขอบของช่องกรอก
                          labelText: 'Visibility', // ข้อความชื่อช่องที่แสดงในฟอร์ม
                          prefixIcon: const Icon(Icons.filter_list_rounded), // ไอคอนด้านหน้าของช่องกรอก
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12), // ความโค้งของมุมกรอบ
                          ),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 'All', // ตัวเลือกให้แสดงทุกสถานะ
                            child: Text('All'),
                          ),
                          ..._statuses.map(
                            (status) => DropdownMenuItem(
                              value: status, // ส่งรหัส private/public ของตัวเลือกนี้กลับเมื่อเลือก
                              child: Text(mangaVisibilityLabel(status)),
                            ),
                          ),
                        ],
                        onChanged: (value) { // ทำงานทันทีเมื่อค่าช่องหรือรายการเลือกเปลี่ยน
                          if (value != null) {
                            setState(() => _selectedStatus = value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28), // เว้นระยะห่างแนวตั้ง 28 พิกเซล
              // เลือกแสดงตัวโหลด ข้อผิดพลาด ข้อความว่าง หรือการ์ด Manga
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(36), // ระยะว่างด้านในระหว่างขอบกับเนื้อหา
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_loadError != null)
                _MessageState(
                  icon: Icons.cloud_off_outlined,
                  title: 'โหลดรายการไม่สำเร็จ',
                  message: _loadError!,
                  actionLabel: 'ลองอีกครั้ง',
                  onAction: _loadManga,
                )
              else if (_visibleManga.isEmpty)
                _MessageState(
                  icon: _manga.isEmpty
                      ? Icons.auto_stories_outlined
                      : Icons.search_off,
                  title: _manga.isEmpty
                      ? 'ยังไม่มี Manga ในชั้น'
                      : 'ไม่พบรายการ',
                  message: _manga.isEmpty
                      ? 'เพิ่มเรื่องแรกของคุณเพื่อเริ่มจัดชั้นหนังสือ'
                      : 'ลองเปลี่ยนคำค้นหาหรือตัวกรองสถานะ',
                )
              else ...[
                Text(
                  '${_showPublic ? 'รายการสาธารณะ' : 'รายการของฉัน'} (${_visibleManga.length})',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12), // เว้นระยะห่างแนวตั้ง 12 พิกเซล
                ..._visibleManga.map(
                  (manga) => MangaCard(
                    manga: manga,
                    accessToken: widget.user['access_token'].toString(),
                    onTap: () => _openManga(manga), // ทำงานเมื่อแตะการ์ดหรือรายการนี้
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // เปิดหน้ารายละเอียดและโหลดรายการใหม่เมื่อกลับมา เพื่อเห็นข้อมูลที่แก้ไข
  Future<void> _openManga(Map<String, dynamic> manga) async {
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
    if (mounted) await _loadManga();
  }
}

/// หัวเรื่องของ Dashboard ปรับข้อความตามแท็บของฉันหรือสาธารณะ
class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.username, required this.showPublic});

  final String username;
  final bool showPublic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24), // ระยะว่างด้านในระหว่างขอบกับเนื้อหา
      decoration: BoxDecoration( // กำหนดสี ขอบ หรือเงาของกล่องนี้
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primaryContainer, colors.secondaryContainer],
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
                  'สวัสดี, $username',
                  maxLines: 2, // แสดงข้อความได้สูงสุดสองบรรทัด
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 8), // เว้นระยะห่างแนวตั้ง 8 พิกเซล
                Text(
                  showPublic ? 'สำรวจ Manga สาธารณะ' : 'ชั้นหนังสือของคุณ',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12), // เว้นระยะห่างแนวนอน 12 พิกเซล
          Icon(
            Icons.auto_stories_rounded,
            size: 48,
            color: colors.onPrimaryContainer.withValues(alpha: 0.72),
          ),
        ],
      ),
    );
  }
}

/// ช่องตัวเลขสรุปที่ใช้ซ้ำบน Dashboard
class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(18), // ระยะว่างด้านในระหว่างขอบกับเนื้อหา
      decoration: BoxDecoration( // กำหนดสี ขอบ หรือเงาของกล่องนี้
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(20), // ความโค้งของมุมกรอบ
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // จัดแนวลูกตามแกนขวางของ Row หรือ Column
        children: [
          Container(
            width: 40, // ความกว้างของพื้นที่แสดงหรือรูปภาพ
            height: 40, // ความสูงของพื้นที่แสดงหรือรูปภาพ
            decoration: BoxDecoration( // กำหนดสี ขอบ หรือเงาของกล่องนี้
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12), // ความโค้งของมุมกรอบ
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 14), // เว้นระยะห่างแนวตั้ง 14 พิกเซล
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
            ),
          ),
          Text(
            label,
            maxLines: 1, // แสดงข้อความเพียงบรรทัดเดียว
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// แสดงข้อความขณะไม่มีข้อมูล โหลดผิดพลาด หรือให้ผู้ใช้ลองใหม่
class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity, // ความกว้างของพื้นที่แสดงหรือรูปภาพ
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24), // ระยะว่างด้านในระหว่างขอบกับเนื้อหา
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
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6), // เว้นระยะห่างแนวตั้ง 6 พิกเซล
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 18), // เว้นระยะห่างแนวตั้ง 18 พิกเซล
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

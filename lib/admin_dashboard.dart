import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'config.dart';
import 'manga_detail.dart';

/// แผงผู้ดูแลสำหรับบัญชีและรีพอร์ต; API ยังตรวจ role จากฐานข้อมูลเอง
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  // State แยกข้อมูลผู้ใช้ รีพอร์ต ตัวกรอง และสถานะของแต่ละแท็บ
  final _search = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _reports = [];
  bool _loadingUsers = true;
  bool _loadingReports = true;
  bool _busy = false;
  bool _showPending = true;
  String? _usersError;
  String? _reportsError;

  // ส่วนหัวร่วมของ admin API พร้อม Bearer token
  Map<String, String> get _headers => {
    'Content-Type': 'application/json; charset=UTF-8',
    'Authorization': 'Bearer ${widget.user['access_token']}',
  };

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  // รีโหลดทั้งแท็บผู้ใช้และแท็บรีพอร์ตหลังการจัดการ
  void _refresh() {
    _loadUsers();
    _loadReports();
  }

  // ตัวช่วย GET ที่ตรวจ statusCode และ success ก่อนคืน JSON
  Future<Map<String, dynamic>> _get(String endpoint) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/$endpoint'),
      headers: _headers, // ส่ง HTTP headers เช่น Bearer token ไปกับคำขอ
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'โหลดข้อมูลไม่สำเร็จ');
    }
    return data;
  }

  // ตัวช่วย POST คำสั่งผู้ดูแลในรูป JSON
  Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/$endpoint'),
      headers: _headers, // ส่ง HTTP headers เช่น Bearer token ไปกับคำขอ
      body: jsonEncode(body), // แปลงข้อมูลเป็น JSON สำหรับส่งให้ PHP API
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'ดำเนินการไม่สำเร็จ');
    }
    return data;
  }

  // โหลดบัญชีพร้อมสถิติ Manga/คอมเมนต์และสถานะพักบัญชี
  Future<void> _loadUsers() async {
    if (mounted) setState(() => _loadingUsers = true);
    try {
      final data = await _get('admin_get_users.php');
      if (!mounted) return;
      setState(() {
        _users = (data['users'] as List<dynamic>)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        _usersError = null;
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _usersError = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  // โหลดรายการแจ้งปัญหาและผลการพิจารณา
  Future<void> _loadReports() async {
    if (mounted) setState(() => _loadingReports = true);
    try {
      final data = await _get('admin_get_reports.php');
      if (!mounted) return;
      setState(() {
        _reports = (data['reports'] as List<dynamic>)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        _reportsError = null;
      });
    } catch (error) {
      if (mounted) {
        setState(
          () =>
              _reportsError = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingReports = false);
    }
  }

  // แสดงผลสำเร็จหรือข้อผิดพลาดเป็น SnackBar
  void _message(Object message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.toString().replaceFirst('Exception: ', '')),
      ),
    );
  }

  // กล่องยืนยันก่อนคำสั่งที่เปลี่ยนข้อมูลผู้ใช้หรือ Manga
  Future<bool> _confirm(String title, String detail) async {
    final answer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(detail),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), // ปิดหน้าหรือ dialog และส่งผลกลับ
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true), // ปิดหน้าหรือ dialog และส่งผลกลับ
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
    return answer == true;
  }

  // พักหรือคืนบัญชีตามสถานะปัจจุบันและโหลดข้อมูลใหม่
  Future<void> _setSuspended(Map<String, dynamic> user) async {
    final suspend = user['is_suspended'] != true;
    final name = user['username'].toString();
    if (!await _confirm(
      suspend ? 'พักบัญชี $name' : 'ปลดพักบัญชี $name',
      suspend
          ? 'ผู้ใช้นี้จะเข้าสู่ระบบและเรียก API ไม่ได้จนกว่าจะปลดพัก'
          : 'ผู้ใช้นี้จะเข้าสู่ระบบได้อีกครั้ง',
    )) {
      return;
    }
    setState(() => _busy = true);
    try {
      final data = await _post('admin_suspend_user.php', {
        'user_id': user['user_id'],
        'is_suspended': suspend,
      });
      _message(data['message'] ?? 'บันทึกแล้ว');
      _refresh();
    } catch (error) {
      _message(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ลบบัญชีหลังยืนยัน; PHP ตรวจเงื่อนไขการลบอีกครั้ง
  Future<void> _deleteUser(Map<String, dynamic> user) async {
    if (!await _confirm(
      'ลบผู้ใช้ ${user['username']}',
      'บัญชี Manga ตอน และความคิดเห็นของผู้ใช้นี้จะถูกลบถาวร',
    )) {
      return;
    }
    setState(() => _busy = true);
    try {
      final data = await _post('admin_delete_user.php', {
        'user_id': user['user_id'],
      });
      _message(data['message'] ?? 'ลบผู้ใช้แล้ว');
      _refresh();
    } catch (error) {
      _message(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // แปลงรหัส action ของรีพอร์ตเป็นชื่อที่อ่านง่ายในกล่องยืนยัน
  String _actionName(String action) => switch (action) {
    'dismissed' => 'ไม่พบปัญหา',
    'hidden' => 'ซ่อน Manga',
    'manga_deleted' => 'ลบ Manga',
    'user_suspended' => 'พักผู้อัปโหลด',
    _ => 'รอตรวจ',
  };

  // ส่งผลพิจารณารีพอร์ต: ปิด ซ่อน ลบเรื่อง หรือพักผู้ลง
  Future<void> _review(Map<String, dynamic> report, String action) async {
    final name = _actionName(action);
    if (!await _confirm(
      name,
      'รีพอร์ตเรื่อง “${report['manga_title']}” จะถูกปิดด้วยผล: $name',
    )) {
      return;
    }
    setState(() => _busy = true);
    try {
      final data = await _post('admin_review_report.php', {
        'report_id': report['report_id'],
        'action': action,
      });
      _message(data['message'] ?? 'บันทึกผลรีพอร์ตแล้ว');
      _refresh();
    } catch (error) {
      _message(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // คืนการแสดงเรื่องที่ถูกซ่อนหลังผู้ดูแลยืนยัน
  Future<void> _restoreManga(Map<String, dynamic> report) async {
    if (!await _confirm(
      'คืนการแสดง Manga',
      'ให้เรื่อง “${report['manga_title']}” กลับมาแสดงสาธารณะหรือไม่?',
    )) {
      return;
    }
    setState(() => _busy = true);
    try {
      final data = await _post('admin_set_manga_hidden.php', {
        'manga_id': report['manga_id'],
        'is_hidden': false,
      });
      _message(data['message'] ?? 'คืนการแสดงแล้ว');
      _refresh();
    } catch (error) {
      _message(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // แปลงข้อมูลในรีพอร์ตเป็น Manga ที่เปิดดูรายละเอียดได้
  void _inspectReport(Map<String, dynamic> report) {
    final mangaId = report['manga_id'];
    if (mangaId == null) return;
    final manga = <String, dynamic>{
      'manga_id': mangaId,
      'user_id': report['manga_owner_id'],
      'title': report['current_title'] ?? report['manga_title'],
      'author': report['author'],
      'genre': report['genre'],
      'genres': report['genres'],
      'release_status': report['release_status'],
      'cover_filename': report['cover_filename'],
      'chapter_count': report['chapter_count'],
      'view_count': report['view_count'],
      'rating_count': report['rating_count'],
      'rating_average': report['rating_average'],
      'description': report['description'],
      'status': report['manga_status'],
      'is_hidden': report['is_hidden'],
      'username': report['uploader_username'],
      'created_at': report['manga_created_at'],
    };
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MangaDetailPage(
          manga: manga,
          accessToken: widget.user['access_token'].toString(),
          canEdit: false,
          canReport: false,
        ),
      ),
    );
  }

  // สร้างรายการผู้ใช้ พร้อมช่องค้นหาและเมนูจัดการแต่ละบัญชี
  Widget _usersView() {
    if (_loadingUsers) return const Center(child: CircularProgressIndicator());
    if (_usersError != null) {
      return Center(
        child: TextButton(
          onPressed: _loadUsers, // เรียก callback นี้เมื่อผู้ใช้กดปุ่ม
          child: Text('$_usersError — ลองอีกครั้ง'),
        ),
      );
    }
    final query = _search.text.trim().toLowerCase();
    final users = _users
        .where(
          (user) => user['username'].toString().toLowerCase().contains(query),
        )
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12), // ระยะว่างด้านในระหว่างขอบกับเนื้อหา
          child: TextField(
            controller: _search, // เก็บคำค้นหาผู้ใช้ใน Admin
            onChanged: (_) => setState(() {}), // ทำงานทันทีเมื่อค่าช่องหรือรายการเลือกเปลี่ยน
            decoration: const InputDecoration(
              labelText: 'ค้นหาผู้ใช้', // ข้อความชื่อช่องที่แสดงในฟอร์ม
              prefixIcon: Icon(Icons.search), // ไอคอนด้านหน้าของช่องกรอก
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: users.length, // จำนวนรายการที่ ListView หรือ PageView ต้องสร้าง
            itemBuilder: (context, index) { // สร้าง widget ของแต่ละรายการตาม index
              final user = users[index];
              final isAdmin = user['role'] == 'admin';
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), // ระยะว่างด้านนอกระหว่าง widget กับบริเวณรอบข้าง
                child: ListTile(
                  title: Text(user['username'].toString()),
                  subtitle: Text(
                    '${isAdmin ? 'admin' : (user['is_suspended'] == true ? 'พักบัญชี' : 'ใช้งานได้')} · '
                    '${user['manga_count']} Manga · ${user['comment_count']} ความคิดเห็น · '
                    '${user['pending_report_count']} รีพอร์ตรอตรวจ\n'
                    'สมัครเมื่อ ${user['created_at']}',
                  ),
                  isThreeLine: true,
                  trailing: isAdmin
                      ? null
                      : PopupMenuButton<String>(
                          tooltip: 'จัดการผู้ใช้',
                          enabled: !_busy,
                          onSelected: (value) => value == 'delete'
                              ? _deleteUser(user)
                              : _setSuspended(user),
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'suspend', // รหัสเมนูสำหรับพักหรือคืนสถานะบัญชี
                              child: Text(
                                user['is_suspended'] == true
                                    ? 'ปลดพักบัญชี'
                                    : 'พักบัญชี',
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete', // รหัสเมนูสำหรับลบบัญชี
                              child: Text('ลบผู้ใช้'),
                            ),
                          ],
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // แสดงคิวรีพอร์ตและปุ่ม action ตามสถานะของแต่ละรายการ
  Widget _reportsView() {
    if (_loadingReports) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_reportsError != null) {
      return Center(
        child: TextButton(
          onPressed: _loadReports, // เรียก callback นี้เมื่อผู้ใช้กดปุ่ม
          child: Text('$_reportsError — ลองอีกครั้ง'),
        ),
      );
    }
    final reports = _reports
        .where((report) => (report['status'] == 'pending') == _showPending)
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12), // ระยะว่างด้านในระหว่างขอบกับเนื้อหา
          child: Wrap(
            spacing: 8, // ระยะห่างระหว่าง widget ที่อยู่บรรทัดเดียวกัน
            children: [
              ChoiceChip(
                label: const Text('รอตรวจ'),
                selected: _showPending, // กำหนดว่าชิปนี้อยู่ในสถานะเลือกหรือไม่
                onSelected: (_) => setState(() => _showPending = true), // ทำงานเมื่อเลือกชิปนี้
              ),
              ChoiceChip(
                label: const Text('ดำเนินการแล้ว'),
                selected: !_showPending, // กำหนดว่าชิปนี้อยู่ในสถานะเลือกหรือไม่
                onSelected: (_) => setState(() => _showPending = false), // ทำงานเมื่อเลือกชิปนี้
              ),
            ],
          ),
        ),
        Expanded(
          child: reports.isEmpty
              ? const Center(child: Text('ไม่มีรีพอร์ตในรายการนี้'))
              : ListView.builder(
                  itemCount: reports.length, // จำนวนรายการที่ ListView หรือ PageView ต้องสร้าง
                  itemBuilder: (context, index) { // สร้าง widget ของแต่ละรายการตาม index
                    final report = reports[index];
                    final pending = report['status'] == 'pending';
                    return Card(
                      margin: const EdgeInsets.symmetric( // ระยะว่างด้านนอกระหว่าง widget กับบริเวณรอบข้าง
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14), // ระยะว่างด้านในระหว่างขอบกับเนื้อหา
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, // จัดแนวลูกตามแกนขวางของ Row หรือ Column
                          children: [
                            Text(
                              report['manga_title'].toString(),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              'ผู้อัปโหลด: ${report['uploader_username']} · ผู้รีพอร์ต: ${report['reporter_username']}',
                            ),
                            Text('วันที่: ${report['created_at']}'),
                            const SizedBox(height: 8), // เว้นระยะห่างแนวตั้ง 8 พิกเซล
                            Text(report['reason'].toString()),
                            const SizedBox(height: 8), // เว้นระยะห่างแนวตั้ง 8 พิกเซล
                            if (report['manga_id'] != null)
                              OutlinedButton.icon(
                                onPressed: () => _inspectReport(report), // เรียก callback นี้เมื่อผู้ใช้กดปุ่ม
                                icon: const Icon(Icons.menu_book_outlined),
                                label: const Text('ดูเรื่อง'),
                              ),
                            if (pending)
                              Wrap(
                                spacing: 8, // ระยะห่างระหว่าง widget ที่อยู่บรรทัดเดียวกัน
                                children: [
                                  OutlinedButton(
                                    onPressed: _busy
                                        ? null
                                        : () => _review(report, 'dismissed'),
                                    child: const Text('ไม่พบปัญหา'),
                                  ),
                                  if (report['manga_id'] != null) ...[
                                    OutlinedButton(
                                      onPressed: _busy
                                          ? null
                                          : () => _review(report, 'hidden'),
                                      child: const Text('ซ่อนเรื่อง'),
                                    ),
                                    OutlinedButton(
                                      onPressed: _busy
                                          ? null
                                          : () => _review(
                                              report,
                                              'manga_deleted',
                                            ),
                                      child: const Text('ลบเรื่อง'),
                                    ),
                                  ],
                                  if (report['uploader_user_id'] != null)
                                    OutlinedButton(
                                      onPressed: _busy
                                          ? null
                                          : () => _review(
                                              report,
                                              'user_suspended',
                                            ),
                                      child: const Text('พักผู้อัปโหลด'),
                                    ),
                                ],
                              )
                            else ...[
                              Text(
                                'ผล: ${_actionName(report['action'].toString())} · '
                                '${report['reviewed_at']} · ผู้ตรวจ: ${report['reviewer_username'] ?? '-'}',
                              ),
                              if (report['manga_id'] != null &&
                                  report['is_hidden'] == true)
                                OutlinedButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _restoreManga(report),
                                  child: const Text('คืนการแสดงเรื่อง'),
                                ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: [
          IconButton(
            tooltip: 'โหลดข้อมูลใหม่',
            onPressed: _refresh, // เรียก callback นี้เมื่อผู้ใช้กดปุ่ม
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: const TabBar(
          tabs: [
            Tab(text: 'ผู้ใช้'),
            Tab(text: 'รีพอร์ต'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_busy) const LinearProgressIndicator(),
          Expanded(child: TabBarView(children: [_usersView(), _reportsView()])),
        ],
      ),
    ),
  );
}

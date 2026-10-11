import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'config.dart';
import 'manga_detail.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _reports = [];
  bool _loadingUsers = true;
  bool _loadingReports = true;
  bool _busy = false;
  bool _showPending = true;
  String? _usersError;
  String? _reportsError;

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

  void _refresh() {
    _loadUsers();
    _loadReports();
  }

  Future<Map<String, dynamic>> _get(String endpoint) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/$endpoint'),
      headers: _headers,
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'โหลดข้อมูลไม่สำเร็จ');
    }
    return data;
  }

  Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/$endpoint'),
      headers: _headers,
      body: jsonEncode(body),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'ดำเนินการไม่สำเร็จ');
    }
    return data;
  }

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

  void _message(Object message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.toString().replaceFirst('Exception: ', '')),
      ),
    );
  }

  Future<bool> _confirm(String title, String detail) async {
    final answer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(detail),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
    return answer == true;
  }

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

  String _actionName(String action) => switch (action) {
    'dismissed' => 'ไม่พบปัญหา',
    'hidden' => 'ซ่อน Manga',
    'manga_deleted' => 'ลบ Manga',
    'user_suspended' => 'พักผู้อัปโหลด',
    _ => 'รอตรวจ',
  };

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

  void _inspectReport(Map<String, dynamic> report) {
    final mangaId = report['manga_id'];
    if (mangaId == null) return;
    final manga = <String, dynamic>{
      'manga_id': mangaId,
      'user_id': report['manga_owner_id'],
      'title': report['current_title'] ?? report['manga_title'],
      'author': report['author'],
      'genre': report['genre'],
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

  Widget _usersView() {
    if (_loadingUsers) return const Center(child: CircularProgressIndicator());
    if (_usersError != null) {
      return Center(
        child: TextButton(
          onPressed: _loadUsers,
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
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'ค้นหาผู้ใช้',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final isAdmin = user['role'] == 'admin';
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                              value: 'suspend',
                              child: Text(
                                user['is_suspended'] == true
                                    ? 'ปลดพักบัญชี'
                                    : 'พักบัญชี',
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
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

  Widget _reportsView() {
    if (_loadingReports) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_reportsError != null) {
      return Center(
        child: TextButton(
          onPressed: _loadReports,
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
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('รอตรวจ'),
                selected: _showPending,
                onSelected: (_) => setState(() => _showPending = true),
              ),
              ChoiceChip(
                label: const Text('ดำเนินการแล้ว'),
                selected: !_showPending,
                onSelected: (_) => setState(() => _showPending = false),
              ),
            ],
          ),
        ),
        Expanded(
          child: reports.isEmpty
              ? const Center(child: Text('ไม่มีรีพอร์ตในรายการนี้'))
              : ListView.builder(
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    final pending = report['status'] == 'pending';
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              report['manga_title'].toString(),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              'ผู้อัปโหลด: ${report['uploader_username']} · ผู้รีพอร์ต: ${report['reporter_username']}',
                            ),
                            Text('วันที่: ${report['created_at']}'),
                            const SizedBox(height: 8),
                            Text(report['reason'].toString()),
                            const SizedBox(height: 8),
                            if (report['manga_id'] != null)
                              OutlinedButton.icon(
                                onPressed: () => _inspectReport(report),
                                icon: const Icon(Icons.menu_book_outlined),
                                label: const Text('ดูเรื่อง'),
                              ),
                            if (pending)
                              Wrap(
                                spacing: 8,
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
            onPressed: _refresh,
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

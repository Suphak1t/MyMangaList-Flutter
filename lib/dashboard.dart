import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'add_manga_dialog.dart';
import 'admin_dashboard.dart';
import 'config.dart';
import 'manga_detail.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.user, this.onLogout});

  final Map<String, dynamic> user;
  final VoidCallback? onLogout;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const _statuses = [
    'Reading',
    'Completed',
    'Plan to Read',
    'On Hold',
    'Dropped',
  ];

  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _manga = [];
  String _selectedStatus = 'All';
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

  Future<void> _loadManga() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/manga_get.php'),
        headers: {'Authorization': 'Bearer ${widget.user['access_token']}'},
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200 || data['success'] != true) {
        throw Exception(data['message'] ?? 'โหลดรายการ Manga ไม่สำเร็จ');
      }

      final items = data['manga'] as List<dynamic>? ?? [];
      if (!mounted) return;
      setState(() {
        _manga = items
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
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

  Future<void> _addManga() async {
    final manga = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const AddMangaDialog(),
    );
    if (manga == null) return;

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/manga_add.php'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer ${widget.user['access_token']}',
        },
        body: jsonEncode(manga),
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200 || data['success'] != true) {
        throw Exception(data['message'] ?? 'เพิ่ม Manga ไม่สำเร็จ');
      }

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

  List<Map<String, dynamic>> get _visibleManga {
    final query = _searchController.text.trim().toLowerCase();
    return _manga.where((item) {
      final matchesStatus =
          _selectedStatus == 'All' || item['status'] == _selectedStatus;
      final searchable = [
        item['title'],
        item['author'],
        item['genre'],
      ].whereType<String>().join(' ').toLowerCase();
      return matchesStatus && (query.isEmpty || searchable.contains(query));
    }).toList();
  }

  String _statusLabel(String status) => switch (status) {
    'Reading' => 'กำลังอ่าน',
    'Completed' => 'อ่านจบแล้ว',
    'Plan to Read' => 'วางแผนจะอ่าน',
    'On Hold' => 'พักไว้ก่อน',
    'Dropped' => 'เลิกอ่าน',
    _ => status,
  };

  Color _statusColor(String status) => switch (status) {
    'Reading' => Colors.teal,
    'Completed' => Colors.green,
    'On Hold' => Colors.orange,
    'Dropped' => Colors.redAccent,
    _ => Colors.blueGrey,
  };

  @override
  Widget build(BuildContext context) {
    final isAdmin = (widget.user['role'] ?? '').toString() == 'admin';
    final readingCount = _manga
        .where((item) => item['status'] == 'Reading')
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MyMangaList'),
        actions: [
          if (isAdmin)
            IconButton(
              tooltip: 'จัดการผู้ใช้',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AdminDashboardPage(user: widget.user),
                ),
              ),
              icon: const Icon(Icons.admin_panel_settings_outlined),
            ),
          IconButton(
            tooltip: 'ออกจากระบบ',
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addManga,
        icon: const Icon(Icons.add),
        label: const Text('เพิ่ม Manga'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadManga,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
          children: [
            Text(
              'สวัสดี, ${widget.user['username'] ?? 'นักอ่าน'}',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'ชั้นหนังสือของคุณ',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _SummaryTile(
                    label: 'ทั้งหมด',
                    value: '${_manga.length}',
                    icon: Icons.auto_stories_outlined,
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryTile(
                    label: 'กำลังอ่าน',
                    value: '$readingCount',
                    icon: Icons.menu_book_outlined,
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'ค้นหาชื่อเรื่อง ผู้แต่ง หรือแนว',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'ล้างคำค้นหา',
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close),
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: const InputDecoration(
                labelText: 'กรองตามสถานะ',
                prefixIcon: Icon(Icons.filter_list),
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: 'All', child: Text('ทุกสถานะ')),
                ..._statuses.map(
                  (status) => DropdownMenuItem(
                    value: status,
                    child: Text(_statusLabel(status)),
                  ),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _selectedStatus = value);
              },
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(36),
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
                title: _manga.isEmpty ? 'ยังไม่มี Manga ในชั้น' : 'ไม่พบรายการ',
                message: _manga.isEmpty
                    ? 'เพิ่มเรื่องแรกของคุณเพื่อเริ่มจัดชั้นหนังสือ'
                    : 'ลองเปลี่ยนคำค้นหาหรือตัวกรองสถานะ',
              )
            else ...[
              Text(
                'รายการของฉัน (${_visibleManga.length})',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ..._visibleManga.map(_buildMangaTile),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMangaTile(Map<String, dynamic> manga) {
    final status = (manga['status'] ?? 'Plan to Read').toString();
    final subtitleParts = [
      manga['author'],
      manga['genre'],
    ].whereType<String>().where((value) => value.isNotEmpty).toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _statusColor(status).withValues(alpha: 0.12),
          foregroundColor: _statusColor(status),
          child: const Icon(Icons.book_outlined),
        ),
        title: Text(
          (manga['title'] ?? '').toString(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          [
            if (subtitleParts.isNotEmpty) subtitleParts.join(' · '),
            _statusLabel(status),
          ].join('\n'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: subtitleParts.isNotEmpty,
        onTap: () async {
          await Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (context) => MangaDetailPage(
                manga: manga,
                accessToken: widget.user['access_token'].toString(),
              ),
            ),
          );
          if (mounted) await _loadManga();
        },
      ),
    );
  }
}

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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 16),
      child: Column(
        children: [
          Icon(icon, size: 42, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

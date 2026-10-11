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

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.user, this.onLogout});

  final Map<String, dynamic> user;
  final VoidCallback? onLogout;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const _statuses = ['private', 'public'];

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

  Future<void> _loadManga() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final headers = {
        'Authorization': 'Bearer ${widget.user['access_token']}',
      };
      final responses = await Future.wait([
        http.get(
          Uri.parse(
            '${ApiConfig.baseUrl}/manga_get.php${_showPublic ? '?scope=public' : ''}',
          ),
          headers: headers,
        ),
        http.get(
          Uri.parse('${ApiConfig.baseUrl}/manga_get.php?scope=public'),
          headers: headers,
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

  Future<void> _addManga() async {
    final manga = await showDialog<MangaFormResult>(
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
        body: jsonEncode(manga.fields),
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200 || data['success'] != true) {
        throw Exception(data['message'] ?? 'เพิ่ม Manga ไม่สำเร็จ');
      }

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

  List<Map<String, dynamic>> get _visibleManga {
    final query = _searchController.text.trim().toLowerCase();
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

  String _statusLabel(String status) => switch (status) {
    'private' => 'ส่วนตัว',
    'public' => 'สาธารณะ',
    _ => status,
  };

  @override
  Widget build(BuildContext context) {
    final isAdmin = (widget.user['role'] ?? '').toString() == 'admin';
    final publicCount = _manga
        .where(
          (item) => item['status'] == 'public' && item['is_hidden'] != true,
        )
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MyMangaList'),
        actions: [
          IconButton(
            tooltip: 'ค้นหา Manga',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MangaSearchPage(user: widget.user),
              ),
            ),
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: 'สลับธีมมืด',
            onPressed: toggleAppTheme,
            icon: const Icon(Icons.dark_mode_outlined),
          ),
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
              _showPublic ? 'Manga สาธารณะ' : 'ชั้นหนังสือของคุณ',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('ของฉัน'),
                  selected: !_showPublic,
                  onSelected: (_) {
                    setState(() {
                      _showPublic = false;
                      _selectedStatus = 'All';
                    });
                    _loadManga();
                  },
                ),
                ChoiceChip(
                  label: const Text('สาธารณะ'),
                  selected: _showPublic,
                  onSelected: (_) {
                    setState(() {
                      _showPublic = true;
                      _selectedStatus = 'All';
                    });
                    _loadManga();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
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
                    label: 'สาธารณะ',
                    value: '$publicCount',
                    icon: Icons.menu_book_outlined,
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MangaSearchPage(user: widget.user),
                ),
              ),
              icon: const Icon(Icons.search),
              label: const Text('ไปหน้าค้นหาและกรอง Manga'),
            ),
            const SizedBox(height: 20),
            if (_topManga.isNotEmpty) ...[
              Text(
                'Top 10 ยอดผู้อ่าน',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              ..._topManga.asMap().entries.map(
                (entry) => Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text(
                        '${entry.key + 1}.',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Expanded(
                      child: MangaCard(
                        manga: entry.value,
                        accessToken: widget.user['access_token'].toString(),
                        onTap: () => _openManga(entry.value),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
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
            if (!_showPublic)
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
                '${_showPublic ? 'รายการสาธารณะ' : 'รายการของฉัน'} (${_visibleManga.length})',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ..._visibleManga.map(
                (manga) => MangaCard(
                  manga: manga,
                  accessToken: widget.user['access_token'].toString(),
                  onTap: () => _openManga(manga),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

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

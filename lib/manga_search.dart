import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'config.dart';
import 'genre_options.dart';
import 'manga_card.dart';
import 'manga_detail.dart';

class MangaSearchPage extends StatefulWidget {
  const MangaSearchPage({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<MangaSearchPage> createState() => _MangaSearchPageState();
}

class _MangaSearchPageState extends State<MangaSearchPage> {
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
        headers: {'Authorization': 'Bearer ${widget.user['access_token']}'},
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

  List<Map<String, dynamic>> get _results {
    final text = _query.text.trim().toLowerCase();
    return _manga.where((manga) {
      final genres = manga['genres'] is List
          ? manga['genres'] as List
          : [manga['genre']];
      final haystack = [
        manga['title'],
        manga['author'],
        ...genres,
      ].whereType<String>().join(' ').toLowerCase();
      return (text.isEmpty || haystack.contains(text)) &&
          (_selectedGenres.isEmpty ||
              genres.any((genre) => _selectedGenres.contains(genre))) &&
          (_release == 'all' || manga['release_status'] == _release) &&
          (_public || _visibility == 'all' || manga['status'] == _visibility);
    }).toList();
  }

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
              borderRadius: BorderRadius.circular(24),
            ),
            content: SizedBox(
              width: 400,
              height: 430,
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'ค้นหาแนวเรื่อง',
                      prefixIcon: const Icon(Icons.search_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (value) => updateDialog(() => query = value),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final genre = filtered[index];
                        return CheckboxListTile(
                          title: Text(genre),
                          value: _selectedGenres.contains(genre),
                          onChanged: (checked) {
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
                onPressed: () {
                  updateDialog(_selectedGenres.clear);
                  setState(() {});
                },
                child: const Text('ล้างที่เลือก'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
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
      borderRadius: BorderRadius.circular(12),
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
            padding: EdgeInsets.fromLTRB(
              ((constraints.maxWidth - 760) / 2).clamp(20.0, double.infinity),
              24,
              ((constraints.maxWidth - 760) / 2).clamp(20.0, double.infinity),
              40,
            ),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.primaryContainer,
                      colors.secondaryContainer,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ค้นหาเรื่องที่คุณชอบ',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colors.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'เลือกแนวเรื่องและสถานะเพื่อค้นหา Manga',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.travel_explore_rounded,
                      size: 44,
                      color: colors.onPrimaryContainer.withValues(alpha: 0.72),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'ตัวกรองการค้นหา',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _query,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'ชื่อเรื่อง ผู้แต่ง หรือแนวเรื่อง',
                        prefixIcon: const Icon(Icons.search_rounded),
                        border: fieldBorder,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          avatar: const Icon(Icons.public_rounded, size: 18),
                          label: const Text('สาธารณะ'),
                          selected: _public,
                          onSelected: (_) {
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
                          selected: !_public,
                          onSelected: (_) {
                            setState(() => _public = false);
                            _load();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _chooseGenres,
                      icon: const Icon(Icons.category_outlined),
                      label: Text(
                        _selectedGenres.isEmpty
                            ? 'ประเภทการ์ตูน: ทุกแนว'
                            : 'ประเภทการ์ตูน: เลือก ${_selectedGenres.length} แนว',
                      ),
                    ),
                    if (_selectedGenres.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _selectedGenres
                            .map(
                              (genre) => InputChip(
                                label: Text(genre),
                                onDeleted: () => setState(
                                  () => _selectedGenres.remove(genre),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _release,
                      decoration: InputDecoration(
                        labelText: 'Release status',
                        prefixIcon: const Icon(Icons.schedule_rounded),
                        border: fieldBorder,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All')),
                        DropdownMenuItem(
                          value: 'coming_soon',
                          child: Text('Coming Soon'),
                        ),
                        DropdownMenuItem(
                          value: 'ongoing',
                          child: Text('Ongoing'),
                        ),
                        DropdownMenuItem(
                          value: 'hiatus',
                          child: Text('Hiatus'),
                        ),
                        DropdownMenuItem(
                          value: 'completed',
                          child: Text('Completed'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _release = value ?? 'all'),
                    ),
                    if (!_public) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _visibility,
                        decoration: InputDecoration(
                          labelText: 'Visibility',
                          prefixIcon: const Icon(Icons.filter_list_rounded),
                          border: fieldBorder,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All')),
                          DropdownMenuItem(
                            value: 'private',
                            child: Text('Private'),
                          ),
                          DropdownMenuItem(
                            value: 'public',
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
              const SizedBox(height: 28),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(36),
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
                const SizedBox(height: 12),
                ...results.map(
                  (manga) => MangaCard(
                    manga: manga,
                    accessToken: widget.user['access_token'].toString(),
                    onTap: () => _open(manga),
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
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(icon, size: 44, color: colors.primary),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('ลองอีกครั้ง'),
            ),
          ],
        ],
      ),
    );
  }
}

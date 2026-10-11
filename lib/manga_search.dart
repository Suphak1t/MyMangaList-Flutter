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
            content: SizedBox(
              width: 400,
              height: 430,
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'ค้นหาแนวเรื่อง',
                      prefixIcon: Icon(Icons.search),
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
    return Scaffold(
      appBar: AppBar(title: const Text('ค้นหา Manga')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _query,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'ชื่อเรื่อง ผู้แต่ง หรือแนวเรื่อง',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('สาธารณะ'),
                  selected: _public,
                  onSelected: (_) {
                    setState(() {
                      _public = true;
                    });
                    _load();
                  },
                ),
                ChoiceChip(
                  label: const Text('ของฉัน'),
                  selected: !_public,
                  onSelected: (_) {
                    setState(() {
                      _public = false;
                    });
                    _load();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _chooseGenres,
              icon: const Icon(Icons.checklist),
              label: Text(
                _selectedGenres.isEmpty
                    ? 'ประเภทการ์ตูน: ทุกแนว'
                    : 'ประเภทการ์ตูน: เลือก ${_selectedGenres.length} แนว',
              ),
            ),
            if (_selectedGenres.isNotEmpty)
              Wrap(
                spacing: 6,
                children: _selectedGenres
                    .map(
                      (genre) => InputChip(
                        label: Text(genre),
                        onDeleted: () =>
                            setState(() => _selectedGenres.remove(genre)),
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _release,
              decoration: const InputDecoration(
                labelText: 'Release status',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All')),
                DropdownMenuItem(
                  value: 'coming_soon',
                  child: Text('Coming Soon'),
                ),
                DropdownMenuItem(value: 'ongoing', child: Text('Ongoing')),
                DropdownMenuItem(value: 'hiatus', child: Text('Hiatus')),
                DropdownMenuItem(value: 'completed', child: Text('Completed')),
              ],
              onChanged: (value) => setState(() => _release = value ?? 'all'),
            ),
            if (!_public) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _visibility,
                decoration: const InputDecoration(
                  labelText: 'Visibility',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(value: 'private', child: Text('Private')),
                  DropdownMenuItem(value: 'public', child: Text('Public')),
                ],
                onChanged: (value) =>
                    setState(() => _visibility = value ?? 'all'),
              ),
            ],
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              TextButton(onPressed: _load, child: Text('$_error — ลองอีกครั้ง'))
            else if (_results.isEmpty)
              const Center(child: Text('ไม่พบ Manga ที่ตรงกับตัวกรอง'))
            else ...[
              Text(
                'พบ ${_results.length} เรื่อง',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ..._results.map(
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
    );
  }
}

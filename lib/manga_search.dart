import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'config.dart';
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
  String _genre = 'all';
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
        final available = _manga.expand(
          (manga) => manga['genres'] is List
              ? (manga['genres'] as List).map((value) => value.toString())
              : [(manga['genre'] ?? '').toString()],
        );
        if (_genre != 'all' && !available.contains(_genre)) _genre = 'all';
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
          (_genre == 'all' || genres.contains(_genre)) &&
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

  @override
  Widget build(BuildContext context) {
    final genres =
        _manga
            .expand(
              (manga) => manga['genres'] is List
                  ? (manga['genres'] as List).map((value) => value.toString())
                  : [(manga['genre'] ?? '').toString()],
            )
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
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
                      _genre = 'all';
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
                      _genre = 'all';
                    });
                    _load();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _genre,
              decoration: const InputDecoration(
                labelText: 'ประเภทการ์ตูน',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: 'all', child: Text('ทุกแนว')),
                ...genres.map(
                  (genre) => DropdownMenuItem(value: genre, child: Text(genre)),
                ),
              ],
              onChanged: (value) => setState(() => _genre = value ?? 'all'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _release,
              decoration: const InputDecoration(
                labelText: 'สถานะการ์ตูน',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('ทุกสถานะ')),
                DropdownMenuItem(value: 'ongoing', child: Text('กำลังอัปเดต')),
                DropdownMenuItem(
                  value: 'hiatus',
                  child: Text('ช่วงหยุดอัปโหลด'),
                ),
                DropdownMenuItem(value: 'completed', child: Text('จบแล้ว')),
              ],
              onChanged: (value) => setState(() => _release = value ?? 'all'),
            ),
            if (!_public) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _visibility,
                decoration: const InputDecoration(
                  labelText: 'การมองเห็น',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
                  DropdownMenuItem(value: 'private', child: Text('ส่วนตัว')),
                  DropdownMenuItem(value: 'public', child: Text('สาธารณะ')),
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

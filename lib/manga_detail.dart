import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'add_manga_dialog.dart';
import 'config.dart';

class MangaDetailPage extends StatefulWidget {
  const MangaDetailPage({
    super.key,
    required this.manga,
    required this.accessToken,
  });

  final Map<String, dynamic> manga;
  final String accessToken;

  @override
  State<MangaDetailPage> createState() => _MangaDetailPageState();
}

class _MangaDetailPageState extends State<MangaDetailPage> {
  late Map<String, dynamic> _manga = Map<String, dynamic>.from(widget.manga);
  bool _busy = false;

  Future<void> _request(String endpoint, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/$endpoint'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer ${widget.accessToken}',
      },
      body: jsonEncode(body),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'บันทึกข้อมูลไม่สำเร็จ');
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
    );
  }

  Future<void> _edit() async {
    final changes = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AddMangaDialog(manga: _manga),
    );
    if (changes == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await _request('manga_update.php', {
        'manga_id': _manga['manga_id'],
        ...changes,
      });
      if (!mounted) return;
      setState(() => _manga = {..._manga, ...changes});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('แก้ไข Manga สำเร็จ')));
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบ Manga'),
        content: Text('ต้องการลบ “${_manga['title']}” หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
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

  Widget _field(String label, Object? value) {
    final text = (value ?? '').toString().trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(text.isEmpty ? '—' : text),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('รายละเอียด Manga')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            (_manga['title'] ?? '').toString(),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 20),
          _field('ผู้แต่ง', _manga['author']),
          _field('แนวเรื่อง', _manga['genre']),
          _field('สถานะ', _manga['status']),
          _field('รายละเอียด', _manga['description']),
          const SizedBox(height: 12),
          if (_busy) const Center(child: CircularProgressIndicator()),
          Row(
            children: [
              FilledButton.icon(
                onPressed: _busy ? null : _edit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('แก้ไข'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : _delete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('ลบ'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

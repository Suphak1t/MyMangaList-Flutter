import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'config.dart';

class CommentsPage extends StatefulWidget {
  const CommentsPage({
    super.key,
    required this.mangaId,
    required this.title,
    required this.accessToken,
    this.chapterId,
  });

  final int mangaId;
  final int? chapterId;
  final String title;
  final String accessToken;

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  final _text = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json; charset=UTF-8',
    'Authorization': 'Bearer ${widget.accessToken}',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/comments_get.php').replace(
        queryParameters: {
          'manga_id': '${widget.mangaId}',
          if (widget.chapterId != null) 'chapter_id': '${widget.chapterId}',
        },
      );
      final response = await http.get(uri, headers: _headers);
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || data['success'] != true) {
        throw Exception(data['message'] ?? 'โหลดความคิดเห็นไม่สำเร็จ');
      }
      if (!mounted) return;
      setState(() {
        _comments = (data['comments'] as List<dynamic>)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _post(String endpoint, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/$endpoint'),
      headers: _headers,
      body: jsonEncode(body),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'บันทึกความคิดเห็นไม่สำเร็จ');
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
    );
  }

  Future<void> _add() async {
    final body = _text.text.trim();
    if (body.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await _post('comment_add.php', {
        'manga_id': widget.mangaId,
        if (widget.chapterId != null) 'chapter_id': widget.chapterId,
        'body': body,
      });
      _text.clear();
      await _load();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(int commentId) async {
    setState(() => _busy = true);
    try {
      await _post('comment_delete.php', {'comment_id': commentId});
      await _load();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: Column(
      children: [
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: TextButton(
                    onPressed: _load,
                    child: Text('$_error — ลองอีกครั้ง'),
                  ),
                )
              : _comments.isEmpty
              ? const Center(child: Text('ยังไม่มีความคิดเห็น'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _comments.length,
                  itemBuilder: (context, index) {
                    final comment = _comments[index];
                    return Card(
                      child: ListTile(
                        title: Text((comment['username'] ?? '').toString()),
                        subtitle: Text((comment['body'] ?? '').toString()),
                        trailing: comment['can_delete'] == true
                            ? IconButton(
                                tooltip: 'ลบความคิดเห็น',
                                onPressed: _busy
                                    ? null
                                    : () =>
                                          _delete(comment['comment_id'] as int),
                                icon: const Icon(Icons.delete_outline),
                              )
                            : null,
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    maxLength: 1000,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'เขียนความคิดเห็น',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'ส่งความคิดเห็น',
                  onPressed: _busy ? null : _add,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

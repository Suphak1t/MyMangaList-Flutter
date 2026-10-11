import 'package:flutter/material.dart';

class MangaFormResult {
  const MangaFormResult(this.fields);

  final Map<String, String> fields;
}

class AddMangaDialog extends StatefulWidget {
  const AddMangaDialog({super.key, this.manga});

  final Map<String, dynamic>? manga;

  @override
  State<AddMangaDialog> createState() => _AddMangaDialogState();
}

class _AddMangaDialogState extends State<AddMangaDialog> {
  static const _genres = [
    'Action',
    'Adventure',
    'Comedy',
    'Drama',
    'Ecchi',
    'Fantasy',
    'Horror',
    'Mahou Shoujo',
    'Mecha',
    'Music',
    'Mystery',
    'Psychological',
    'Romance',
    'Sci-Fi',
    'Slice of Life',
    'Sports',
    'Supernatural',
    'Thriller',
  ];

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _genre;
  String _status = 'private';
  String? _selectionError;

  @override
  void initState() {
    super.initState();
    final manga = widget.manga;
    if (manga == null) return;
    _titleController.text = (manga['title'] ?? '').toString();
    _authorController.text = (manga['author'] ?? '').toString();
    final genre = (manga['genre'] ?? '').toString();
    if (_genres.contains(genre)) _genre = genre;
    _descriptionController.text = (manga['description'] ?? '').toString();
    final status = (manga['status'] ?? '').toString();
    if (status == 'public') _status = 'public';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _chooseGenre() async {
    String query = '';
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateSearch) {
          final filtered = _genres
              .where(
                (genre) => genre.toLowerCase().contains(query.toLowerCase()),
              )
              .toList();
          return AlertDialog(
            title: const Text('เลือกแนวเรื่อง'),
            content: SizedBox(
              width: 400,
              height: 430,
              child: Column(
                children: [
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'ค้นหาแนวเรื่อง',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) => updateSearch(() => query = value),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) => ListTile(
                        title: Text(filtered[index]),
                        onTap: () =>
                            Navigator.pop(dialogContext, filtered[index]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _genre = selected;
        _selectionError = null;
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_genre == null) {
      setState(() => _selectionError = 'กรุณาเลือกแนวเรื่อง');
      return;
    }
    Navigator.pop(
      context,
      MangaFormResult({
        'title': _titleController.text.trim(),
        'author': _authorController.text.trim(),
        'genre': _genre!,
        'description': _descriptionController.text.trim(),
        'status': _status,
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.manga == null ? 'เพิ่ม Manga' : 'แก้ไข Manga'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'ชื่อเรื่อง *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'กรุณากรอกชื่อเรื่อง'
                      : null,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _authorController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'ผู้แต่ง',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _chooseGenre,
                  icon: const Icon(Icons.search),
                  label: Text(
                    _genre == null ? 'เลือกแนวเรื่อง *' : 'แนวเรื่อง: $_genre',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _status,
                  decoration: const InputDecoration(
                    labelText: 'สถานะ',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'private', child: Text('ส่วนตัว')),
                    DropdownMenuItem(value: 'public', child: Text('สาธารณะ')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _status = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'รายละเอียด',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'สร้างเรื่องก่อน แล้วเพิ่มไฟล์แยกตามตอนในหน้าเรื่อง',
                ),
                if (_selectionError != null)
                  Text(
                    _selectionError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: Icon(widget.manga == null ? Icons.add : Icons.save_outlined),
          label: const Text('บันทึก'),
        ),
      ],
    );
  }
}

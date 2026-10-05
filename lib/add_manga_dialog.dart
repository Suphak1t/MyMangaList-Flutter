import 'package:flutter/material.dart';

class AddMangaDialog extends StatefulWidget {
  const AddMangaDialog({super.key, this.manga});

  final Map<String, dynamic>? manga;

  @override
  State<AddMangaDialog> createState() => _AddMangaDialogState();
}

class _AddMangaDialogState extends State<AddMangaDialog> {
  static const _statuses = [
    'Reading',
    'Completed',
    'Plan to Read',
    'On Hold',
    'Dropped',
  ];

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _genreController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _status = 'Plan to Read';

  @override
  void initState() {
    super.initState();
    final manga = widget.manga;
    if (manga == null) return;
    _titleController.text = (manga['title'] ?? '').toString();
    _authorController.text = (manga['author'] ?? '').toString();
    _genreController.text = (manga['genre'] ?? '').toString();
    _descriptionController.text = (manga['description'] ?? '').toString();
    final status = (manga['status'] ?? '').toString();
    if (_statuses.contains(status)) _status = status;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _genreController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _statusLabel(String status) => switch (status) {
    'Reading' => 'กำลังอ่าน',
    'Completed' => 'อ่านจบแล้ว',
    'Plan to Read' => 'วางแผนจะอ่าน',
    'On Hold' => 'พักไว้ก่อน',
    'Dropped' => 'เลิกอ่าน',
    _ => status,
  };

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, {
      'title': _titleController.text.trim(),
      'author': _authorController.text.trim(),
      'genre': _genreController.text.trim(),
      'description': _descriptionController.text.trim(),
      'status': _status,
    });
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
                TextField(
                  controller: _genreController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'แนวเรื่อง',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _status,
                  decoration: const InputDecoration(
                    labelText: 'สถานะ',
                    border: OutlineInputBorder(),
                  ),
                  items: _statuses
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(_statusLabel(status)),
                        ),
                      )
                      .toList(),
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

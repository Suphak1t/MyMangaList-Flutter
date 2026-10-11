import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'genre_options.dart';

class MangaFormResult {
  const MangaFormResult(this.fields, this.coverFile);

  final Map<String, dynamic> fields;
  final PlatformFile? coverFile;
}

class AddMangaDialog extends StatefulWidget {
  const AddMangaDialog({super.key, this.manga});

  final Map<String, dynamic>? manga;

  @override
  State<AddMangaDialog> createState() => _AddMangaDialogState();
}

class _AddMangaDialogState extends State<AddMangaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _descriptionController = TextEditingController();
  final Set<String> _selectedGenres = {};
  String _status = 'private';
  String _releaseStatus = 'ongoing';
  PlatformFile? _coverFile;
  String? _selectionError;

  @override
  void initState() {
    super.initState();
    final manga = widget.manga;
    if (manga == null) return;
    _titleController.text = (manga['title'] ?? '').toString();
    _authorController.text = (manga['author'] ?? '').toString();
    final genres = manga['genres'] is List
        ? (manga['genres'] as List).map((value) => value.toString())
        : [(manga['genre'] ?? '').toString()];
    _selectedGenres.addAll(genres.where(mangaGenres.contains));
    _descriptionController.text = (manga['description'] ?? '').toString();
    final status = (manga['status'] ?? '').toString();
    if (status == 'public') _status = 'public';
    final releaseStatus = (manga['release_status'] ?? '').toString();
    if (['ongoing', 'hiatus', 'completed'].contains(releaseStatus)) {
      _releaseStatus = releaseStatus;
    }
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
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateSearch) {
          final filtered = mangaGenres
              .where(
                (genre) => genre.toLowerCase().contains(query.toLowerCase()),
              )
              .toList();
          return AlertDialog(
            title: const Text('เลือกแนวเรื่อง (ได้สูงสุด 5)'),
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
                      itemBuilder: (context, index) => CheckboxListTile(
                        title: Text(filtered[index]),
                        value: _selectedGenres.contains(filtered[index]),
                        onChanged: (checked) {
                          final genre = filtered[index];
                          if (checked == true && _selectedGenres.length >= 5) {
                            return;
                          }
                          updateSearch(() {
                            if (checked == true) {
                              _selectedGenres.add(genre);
                            } else {
                              _selectedGenres.remove(genre);
                            }
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('เสร็จ'),
              ),
            ],
          );
        },
      ),
    );
    if (mounted) setState(() => _selectionError = null);
  }

  Future<void> _chooseCover() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
    );
    if (result != null && mounted) {
      setState(() => _coverFile = result.files.single);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGenres.isEmpty) {
      setState(() => _selectionError = 'กรุณาเลือกแนวเรื่อง');
      return;
    }
    Navigator.pop(
      context,
      MangaFormResult({
        'title': _titleController.text.trim(),
        'author': _authorController.text.trim(),
        'genres': _selectedGenres.toList(),
        'description': _descriptionController.text.trim(),
        'status': _status,
        if (widget.manga != null) 'release_status': _releaseStatus,
      }, _coverFile),
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
                    _selectedGenres.isEmpty
                        ? 'เลือกแนวเรื่อง *'
                        : 'แนวเรื่อง: ${_selectedGenres.join(', ')}',
                  ),
                ),
                if (_selectedGenres.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    children: _selectedGenres
                        .map((genre) => Chip(label: Text(genre)))
                        .toList(),
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
                if (widget.manga != null) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _releaseStatus,
                    decoration: const InputDecoration(
                      labelText: 'สถานะการอัปเดต',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'ongoing',
                        child: Text('กำลังอัปเดต'),
                      ),
                      DropdownMenuItem(
                        value: 'hiatus',
                        child: Text('ช่วงหยุดอัปโหลด'),
                      ),
                      DropdownMenuItem(
                        value: 'completed',
                        child: Text('จบแล้ว'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _releaseStatus = value);
                    },
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _chooseCover,
                  icon: const Icon(Icons.image_outlined),
                  label: Text(
                    _coverFile?.name ?? 'เลือกภาพปก (JPG, PNG, WebP)',
                  ),
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

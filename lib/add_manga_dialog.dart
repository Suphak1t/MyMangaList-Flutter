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
  String? _coverError;
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
    if ([
      'ongoing',
      'hiatus',
      'completed',
      'coming_soon',
    ].contains(releaseStatus)) {
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Text(
              'เลือกแนวเรื่อง (ได้สูงสุด 5)',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            content: SizedBox(
              width: 400,
              height: 430,
              child: Column(
                children: [
                  TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'ค้นหาแนวเรื่อง',
                      prefixIcon: const Icon(Icons.search_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (value) => updateSearch(() => query = value),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) => CheckboxListTile(
                        title: Text(filtered[index]),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                        ),
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
      final file = result.files.single;
      setState(() {
        _coverError = file.size > 5 * 1024 * 1024
            ? 'ภาพปกต้องไม่เกิน 5 MB'
            : null;
        _coverFile = _coverError == null ? file : null;
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_coverError != null) return;
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
        'release_status': _releaseStatus,
      }, _coverFile),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    );
    final focusedBorder = fieldBorder.copyWith(
      borderSide: BorderSide(color: colors.primary, width: 1.5),
    );
    final helperStyle = theme.textTheme.bodyMedium?.copyWith(
      height: 1.45,
      color: colors.onSurfaceVariant,
    );

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      title: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.primaryContainer, colors.secondaryContainer],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.manga == null ? 'เพิ่ม Manga' : 'แก้ไข Manga',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'รายละเอียดเรื่องและการแสดงผล',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              widget.manga == null
                  ? Icons.library_add_outlined
                  : Icons.edit_note_rounded,
              size: 34,
              color: colors.onPrimaryContainer.withValues(alpha: 0.72),
            ),
          ],
        ),
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ข้อมูลเรื่อง',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleController,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  style: theme.textTheme.bodyLarge,
                  decoration: InputDecoration(
                    labelText: 'ชื่อเรื่อง *',
                    prefixIcon: const Icon(Icons.menu_book_outlined),
                    filled: true,
                    fillColor: colors.surfaceContainerLow,
                    border: fieldBorder,
                    enabledBorder: fieldBorder,
                    focusedBorder: focusedBorder,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'กรุณากรอกชื่อเรื่อง'
                      : null,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _authorController,
                  textInputAction: TextInputAction.next,
                  style: theme.textTheme.bodyLarge,
                  decoration: InputDecoration(
                    labelText: 'ผู้แต่ง',
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                    filled: true,
                    fillColor: colors.surfaceContainerLow,
                    border: fieldBorder,
                    enabledBorder: fieldBorder,
                    focusedBorder: focusedBorder,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'แนวเรื่อง *',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _chooseGenre,
                  icon: const Icon(Icons.category_outlined),
                  label: Text(
                    _selectedGenres.isEmpty
                        ? 'เลือกแนวเรื่อง *'
                        : 'เลือกแล้ว ${_selectedGenres.length} แนว',
                  ),
                ),
                if (_selectedGenres.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: _selectedGenres
                        .map((genre) => Chip(label: Text(genre)))
                        .toList(),
                  ),
                ],
                if (_selectionError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _selectionError!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.error,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Divider(color: colors.outlineVariant),
                const SizedBox(height: 16),
                Text(
                  'สถานะเรื่อง',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _status,
                  decoration: InputDecoration(
                    labelText: 'Visibility',
                    prefixIcon: const Icon(Icons.visibility_outlined),
                    filled: true,
                    fillColor: colors.surfaceContainerLow,
                    border: fieldBorder,
                    enabledBorder: fieldBorder,
                    focusedBorder: focusedBorder,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'private', child: Text('Private')),
                    DropdownMenuItem(value: 'public', child: Text('Public')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _status = value);
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _releaseStatus,
                  decoration: InputDecoration(
                    labelText: 'Release status',
                    prefixIcon: const Icon(Icons.schedule_rounded),
                    filled: true,
                    fillColor: colors.surfaceContainerLow,
                    border: fieldBorder,
                    enabledBorder: fieldBorder,
                    focusedBorder: focusedBorder,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: 'ongoing',
                      child: Text('Ongoing'),
                    ),
                    const DropdownMenuItem(
                      value: 'coming_soon',
                      child: Text('Coming Soon'),
                    ),
                    if (widget.manga != null) ...const [
                      DropdownMenuItem(value: 'hiatus', child: Text('Hiatus')),
                      DropdownMenuItem(
                        value: 'completed',
                        child: Text('Completed'),
                      ),
                    ],
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _releaseStatus = value);
                  },
                ),
                const SizedBox(height: 20),
                Divider(color: colors.outlineVariant),
                const SizedBox(height: 16),
                Text(
                  'ภาพปกและรายละเอียด',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text('JPG, PNG, WebP · ไม่เกิน 5 MB', style: helperStyle),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _chooseCover,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('เลือกภาพปก'),
                ),
                if (_coverFile != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _coverFile!.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                if (_coverError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _coverError!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.error,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                TextField(
                  controller: _descriptionController,
                  minLines: 2,
                  maxLines: 4,
                  style: theme.textTheme.bodyLarge,
                  decoration: InputDecoration(
                    labelText: 'รายละเอียด',
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor: colors.surfaceContainerLow,
                    border: fieldBorder,
                    enabledBorder: fieldBorder,
                    focusedBorder: focusedBorder,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'สร้างเรื่องก่อน แล้วเพิ่มไฟล์แยกตามตอนในหน้าเรื่อง',
                  style: helperStyle,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'ยกเลิก',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: Icon(
            widget.manga == null ? Icons.add_rounded : Icons.save_outlined,
            size: 18,
          ),
          label: const Text(
            'บันทึก',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

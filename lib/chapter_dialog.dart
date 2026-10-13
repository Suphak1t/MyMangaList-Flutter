import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class ChapterFormResult {
  const ChapterFormResult(
    this.number,
    this.title,
    this.published,
    this.contentType,
    this.files,
  );

  final int number;
  final String title;
  final bool published;
  final String? contentType;
  final List<PlatformFile> files;
}

class ChapterDialog extends StatefulWidget {
  const ChapterDialog({super.key, required this.nextNumber, this.chapter});

  final int nextNumber;
  final Map<String, dynamic>? chapter;

  @override
  State<ChapterDialog> createState() => _ChapterDialogState();
}

class _ChapterDialogState extends State<ChapterDialog> {
  final _formKey = GlobalKey<FormState>();
  final _number = TextEditingController();
  final _title = TextEditingController();
  bool _published = true;
  String? _contentType;
  List<PlatformFile> _files = [];
  String? _fileError;

  @override
  void initState() {
    super.initState();
    final chapter = widget.chapter;
    _number.text = '${chapter?['chapter_number'] ?? widget.nextNumber}';
    _title.text = (chapter?['title'] ?? '').toString();
    _published = chapter?['is_published'] == true || chapter == null;
  }

  @override
  void dispose() {
    _number.dispose();
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickFiles(String type) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: type == 'pdf'
          ? ['pdf']
          : ['jpg', 'jpeg', 'png', 'webp'],
      allowMultiple: type == 'images',
      withData: false,
    );
    if (picked == null || picked.files.isEmpty || !mounted) return;
    final files = [
      if (type == 'images' && _contentType == 'images') ..._files,
      ...picked.files,
    ]..sort((a, b) => a.name.compareTo(b.name));
    final maxFileSize = (type == 'pdf' ? 20 : 5) * 1024 * 1024;
    final totalSize = files.fold<int>(0, (total, file) => total + file.size);
    final names = files.map((file) => file.name.toLowerCase()).toSet();
    final error = files.any((file) => file.path == null)
        ? 'อ่านไฟล์ที่เลือกไม่ได้'
        : files.length > (type == 'pdf' ? 1 : 15)
        ? 'เลือกภาพได้สูงสุด 15 ไฟล์ต่อตอน'
        : names.length != files.length
        ? 'มีชื่อไฟล์ซ้ำ กรุณาเลือกภาพชื่ออื่น'
        : files.any((file) => file.size > maxFileSize)
        ? type == 'pdf'
              ? 'PDF ต้องไม่เกิน 20 MB'
              : 'ภาพแต่ละไฟล์ต้องไม่เกิน 5 MB'
        : totalSize > 30 * 1024 * 1024
        ? 'ขนาดไฟล์รวมต้องไม่เกิน 30 MB'
        : null;
    setState(() {
      _fileError = error;
      if (error == null) {
        _contentType = type;
        _files = files;
      }
    });
  }

  void _removeFile(int index) {
    setState(() {
      _files.removeAt(index);
      if (_files.isEmpty) _contentType = null;
      _fileError = null;
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (widget.chapter == null && _files.isEmpty) {
      setState(() => _fileError = 'กรุณาเลือก PDF หรือภาพของตอน');
      return;
    }
    if (_files.any((file) => file.path == null)) return;
    if (_fileError != null) return;
    Navigator.pop(
      context,
      ChapterFormResult(
        int.parse(_number.text.trim()),
        _title.text.trim(),
        _published,
        _contentType,
        _files,
      ),
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
    final fieldStyle = theme.textTheme.bodyLarge;
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
                    widget.chapter == null ? 'เพิ่มตอน' : 'แก้ไขตอน',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'รายละเอียดและไฟล์ของตอน',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              widget.chapter == null
                  ? Icons.add_circle_outline_rounded
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
                  'ข้อมูลตอน',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _number,
                  keyboardType: TextInputType.number,
                  style: fieldStyle,
                  decoration: InputDecoration(
                    labelText: 'เลขตอน *',
                    prefixIcon: const Icon(Icons.format_list_numbered_rounded),
                    filled: true,
                    fillColor: colors.surfaceContainerLow,
                    border: fieldBorder,
                    enabledBorder: fieldBorder,
                    focusedBorder: fieldBorder.copyWith(
                      borderSide: BorderSide(color: colors.primary, width: 1.5),
                    ),
                  ),
                  validator: (value) {
                    final number = int.tryParse(value?.trim() ?? '');
                    return number == null || number < 1
                        ? 'กรุณากรอกเลขตอนตั้งแต่ 1'
                        : null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _title,
                  maxLength: 255,
                  style: fieldStyle,
                  decoration: InputDecoration(
                    labelText: 'ชื่อตอน (ไม่บังคับ)',
                    prefixIcon: const Icon(Icons.title_rounded),
                    filled: true,
                    fillColor: colors.surfaceContainerLow,
                    border: fieldBorder,
                    enabledBorder: fieldBorder,
                    focusedBorder: fieldBorder.copyWith(
                      borderSide: BorderSide(color: colors.primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Material(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  child: SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                    title: Text(
                      'เผยแพร่ตอน',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      'เรื่องสาธารณะจึงจะให้ผู้อื่นอ่านได้',
                      style: helperStyle,
                    ),
                    value: _published,
                    onChanged: (value) => setState(() => _published = value),
                  ),
                ),
                const SizedBox(height: 24),
                Divider(color: colors.outlineVariant),
                const SizedBox(height: 16),
                Text(
                  'ไฟล์ของตอน',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PDF 1 ไฟล์ ไม่เกิน 20 MB', style: helperStyle),
                      const SizedBox(height: 4),
                      Text(
                        'หรือภาพ JPG, PNG, WebP สูงสุด 15 ไฟล์ต่อตอน เลือกเพิ่มได้หลายรอบ (ไม่เกิน 5 MB ต่อภาพ และรวมไม่เกิน 30 MB)',
                        style: helperStyle,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ตั้งชื่อภาพตามลำดับ เช่น 001.png, 002.png',
                        style: helperStyle,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _pickFiles('pdf'),
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
                      label: const Text('เลือก PDF'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _contentType == 'images' && _files.length >= 15
                          ? null
                          : () => _pickFiles('images'),
                      icon: const Icon(Icons.collections_outlined, size: 20),
                      label: Text(
                        _contentType == 'images' && _files.isNotEmpty
                            ? 'เพิ่มภาพ (${_files.length}/15)'
                            : 'เลือกภาพ',
                      ),
                    ),
                  ],
                ),
                if (_files.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _contentType == 'images'
                              ? 'ภาพที่เลือก ${_files.length}/15 ไฟล์'
                              : 'PDF ที่เลือก',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (var index = 0; index < _files.length; index++)
                              InputChip(
                                label: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 230,
                                  ),
                                  child: Text(
                                    _files[index].name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                onDeleted: () => _removeFile(index),
                                deleteButtonTooltipMessage: 'ลบภาพที่เลือก',
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                if (widget.chapter != null && _files.isEmpty) ...[
                  const SizedBox(height: 12),
                  Text('ไม่เลือกไฟล์ใหม่ = ใช้ไฟล์เดิม', style: helperStyle),
                ],
                if (_fileError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _fileError!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.error,
                    ),
                  ),
                ],
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
          icon: const Icon(Icons.save_outlined, size: 18),
          label: const Text(
            'บันทึก',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

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
    if (picked == null || !mounted) return;
    final files = picked.files.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    setState(() {
      _contentType = type;
      _files = files;
      _fileError = files.any((file) => file.path == null)
          ? 'อ่านไฟล์ที่เลือกไม่ได้'
          : null;
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (widget.chapter == null && _files.isEmpty) {
      setState(() => _fileError = 'กรุณาเลือก PDF หรือภาพของตอน');
      return;
    }
    if (_files.any((file) => file.path == null)) return;
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
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.chapter == null ? 'เพิ่มตอน' : 'แก้ไขตอน'),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _number,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'เลขตอน *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final number = int.tryParse(value?.trim() ?? '');
                  return number == null || number < 1
                      ? 'กรุณากรอกเลขตอนตั้งแต่ 1'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _title,
                maxLength: 255,
                decoration: const InputDecoration(
                  labelText: 'ชื่อตอน (ไม่บังคับ)',
                  border: OutlineInputBorder(),
                ),
              ),
              SwitchListTile(
                title: const Text('เผยแพร่ตอน'),
                subtitle: const Text('เรื่องสาธารณะจึงจะให้ผู้อื่นอ่านได้'),
                value: _published,
                onChanged: (value) => setState(() => _published = value),
              ),
              const Text(
                'ไฟล์ของตอน: PDF 1 ไฟล์ หรือภาพ JPG, PNG, WebP สูงสุด 15 ไฟล์',
              ),
              const Text('ตั้งชื่อภาพตามลำดับ เช่น 001.png, 002.png'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _pickFiles('pdf'),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('เลือก PDF'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _pickFiles('images'),
                    icon: const Icon(Icons.collections_outlined),
                    label: const Text('เลือกภาพ'),
                  ),
                ],
              ),
              if (_files.isNotEmpty)
                Text(
                  '${_files.length} ไฟล์: ${_files.map((file) => file.name).join(', ')}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              if (widget.chapter != null && _files.isEmpty)
                const Text('ไม่เลือกไฟล์ใหม่ = ใช้ไฟล์เดิม'),
              if (_fileError != null)
                Text(
                  _fileError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
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
      FilledButton(onPressed: _submit, child: const Text('บันทึก')),
    ],
  );
}

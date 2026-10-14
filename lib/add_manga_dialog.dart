import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'genre_options.dart';

/// ผลลัพธ์จากฟอร์ม: metadata สำหรับ JSON และไฟล์ปกสำหรับ multipart
class MangaFormResult {
  const MangaFormResult(this.fields, this.coverFile);

  final Map<String, dynamic> fields;
  final PlatformFile? coverFile;
}

/// ฟอร์มเดียวกันใช้เพิ่มเรื่องหรือแก้ไขเมื่อส่ง manga เดิมเข้ามา
class AddMangaDialog extends StatefulWidget {
  const AddMangaDialog({super.key, this.manga});

  final Map<String, dynamic>? manga;

  @override
  State<AddMangaDialog> createState() => _AddMangaDialogState();
}

class _AddMangaDialogState extends State<AddMangaDialog> {
  // State เก็บค่าช่องกรอก แนวที่ติ๊ก สถานะ ปก และข้อความผิดพลาด
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
    // โหมดแก้ไขเติมข้อมูลเดิม; โหมดเพิ่มคงค่าเริ่มต้นของฟอร์ม
    final manga = widget.manga;
    if (manga == null) return;
    _titleController.text = (manga['title'] ?? '').toString();
    _authorController.text = (manga['author'] ?? '').toString();
    final genres = manga['genres'] is List
        ? (manga['genres'] as List).map((value) => value.toString())
        : [(manga['genre'] ?? '').toString()];
    // เติมแนวเดิมเฉพาะชื่อที่ยังอยู่ในรายการแนวที่รองรับ
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

  // กล่องเลือกแนวค้นหาได้และเลือกพร้อมกันได้ไม่เกิน 5 แนว
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
              borderRadius: BorderRadius.circular(24), // ความโค้งของมุมกรอบ
            ),
            title: Text(
              'เลือกแนวเรื่อง (ได้สูงสุด 5)',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            content: SizedBox(
              width: 400, // ความกว้างของพื้นที่แสดงหรือรูปภาพ
              height: 430, // ความสูงของพื้นที่แสดงหรือรูปภาพ
              child: Column(
                children: [
                  TextField(
                    autofocus: true, // โฟกัสช่องนี้ทันทีเมื่อเปิดหน้าหรือกล่องเลือก
                    decoration: InputDecoration( // กำหนดข้อความและรูปแบบขอบของช่องกรอก
                      hintText: 'ค้นหาแนวเรื่อง', // ข้อความตัวอย่างก่อนผู้ใช้พิมพ์
                      prefixIcon: const Icon(Icons.search_rounded), // ไอคอนด้านหน้าของช่องกรอก
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), // ความโค้งของมุมกรอบ
                      ),
                    ),
                    onChanged: (value) => updateSearch(() => query = value), // ทำงานทันทีเมื่อค่าช่องหรือรายการเลือกเปลี่ยน
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length, // จำนวนรายการที่ ListView หรือ PageView ต้องสร้าง
                      itemBuilder: (context, index) => CheckboxListTile( // สร้าง widget ของแต่ละรายการตาม index
                        title: Text(filtered[index]),
                        contentPadding: const EdgeInsets.symmetric( // ระยะว่างภายในส่วนเนื้อหาของ widget
                          horizontal: 4,
                        ),
                        value: _selectedGenres.contains(filtered[index]), // ติ๊กถูกเมื่อแนวนี้อยู่ในชุดที่เลือก
                        onChanged: (checked) { // ทำงานทันทีเมื่อค่าช่องหรือรายการเลือกเปลี่ยน
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
                onPressed: () => Navigator.pop(dialogContext), // ปิดหน้าหรือ dialog และส่งผลกลับ
                child: const Text('เสร็จ'),
              ),
            ],
          );
        },
      ),
    );
    if (mounted) setState(() => _selectionError = null);
  }

  // เลือกปก JPG/PNG/WebP และตรวจขนาดไม่เกิน 5 MB ก่อนส่งกลับ
  Future<void> _chooseCover() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, // ใช้ชุดนามสกุลไฟล์ที่ระบุเอง
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'], // นามสกุลไฟล์ที่ตัวเลือกไฟล์ยอมให้เลือก
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

  // ตรวจฟอร์มและแนวอย่างน้อยหนึ่งค่า แล้วส่ง MangaFormResult กลับหน้าที่เปิด dialog
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
      borderRadius: BorderRadius.circular(14), // ความโค้งของมุมกรอบ
      borderSide: BorderSide.none,
    );
    final focusedBorder = fieldBorder.copyWith(
      borderSide: BorderSide(color: colors.primary, width: 1.5),
    );
    final helperStyle = theme.textTheme.bodyMedium?.copyWith(
      height: 1.45, // ความสูงบรรทัดของตัวอักษรเป็น 1.45 เท่า
      color: colors.onSurfaceVariant,
    );

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8), // ระยะว่างภายในส่วนเนื้อหาของ widget
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      title: Container(
        padding: const EdgeInsets.all(18), // ระยะว่างด้านในระหว่างขอบกับเนื้อหา
        decoration: BoxDecoration( // กำหนดสี ขอบ หรือเงาของกล่องนี้
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.primaryContainer, colors.secondaryContainer],
          ),
          borderRadius: BorderRadius.circular(20), // ความโค้งของมุมกรอบ
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, // จัดแนวลูกตามแกนขวางของ Row หรือ Column
                children: [
                  Text(
                    widget.manga == null ? 'เพิ่ม Manga' : 'แก้ไข Manga',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4), // เว้นระยะห่างแนวตั้ง 4 พิกเซล
                  Text(
                    'รายละเอียดเรื่องและการแสดงผล',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8), // เว้นระยะห่างแนวนอน 8 พิกเซล
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
        width: 460, // ความกว้างของพื้นที่แสดงหรือรูปภาพ
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min, // กำหนดให้ Row หรือ Column ใช้พื้นที่ตามเนื้อหาหรือเต็มแกน
              crossAxisAlignment: CrossAxisAlignment.start, // จัดแนวลูกตามแกนขวางของ Row หรือ Column
              children: [
                Text(
                  'ข้อมูลเรื่อง',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12), // เว้นระยะห่างแนวตั้ง 12 พิกเซล
                TextFormField(
                  controller: _titleController, // เก็บชื่อ Manga ที่ผู้ใช้กรอก
                  autofocus: true, // โฟกัสช่องนี้ทันทีเมื่อเปิดหน้าหรือกล่องเลือก
                  textInputAction: TextInputAction.next,
                  style: theme.textTheme.bodyLarge,
                  decoration: InputDecoration( // กำหนดข้อความและรูปแบบขอบของช่องกรอก
                    labelText: 'ชื่อเรื่อง *', // ข้อความชื่อช่องที่แสดงในฟอร์ม
                    prefixIcon: const Icon(Icons.menu_book_outlined), // ไอคอนด้านหน้าของช่องกรอก
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
                const SizedBox(height: 14), // เว้นระยะห่างแนวตั้ง 14 พิกเซล
                TextField(
                  controller: _authorController, // เก็บชื่อผู้แต่งที่ผู้ใช้กรอก
                  textInputAction: TextInputAction.next,
                  style: theme.textTheme.bodyLarge,
                  decoration: InputDecoration( // กำหนดข้อความและรูปแบบขอบของช่องกรอก
                    labelText: 'ผู้แต่ง', // ข้อความชื่อช่องที่แสดงในฟอร์ม
                    prefixIcon: const Icon(Icons.person_outline_rounded), // ไอคอนด้านหน้าของช่องกรอก
                    filled: true,
                    fillColor: colors.surfaceContainerLow,
                    border: fieldBorder,
                    enabledBorder: fieldBorder,
                    focusedBorder: focusedBorder,
                  ),
                ),
                const SizedBox(height: 18), // เว้นระยะห่างแนวตั้ง 18 พิกเซล
                Text(
                  'แนวเรื่อง *',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8), // เว้นระยะห่างแนวตั้ง 8 พิกเซล
                OutlinedButton.icon(
                  onPressed: _chooseGenre, // เรียก callback นี้เมื่อผู้ใช้กดปุ่ม
                  icon: const Icon(Icons.category_outlined),
                  label: Text(
                    _selectedGenres.isEmpty
                        ? 'เลือกแนวเรื่อง *'
                        : 'เลือกแล้ว ${_selectedGenres.length} แนว',
                  ),
                ),
                if (_selectedGenres.isNotEmpty) ...[
                  const SizedBox(height: 8), // เว้นระยะห่างแนวตั้ง 8 พิกเซล
                  Wrap(
                    spacing: 6, // ระยะห่างระหว่าง widget ที่อยู่บรรทัดเดียวกัน
                    runSpacing: 4, // ระยะห่างระหว่างบรรทัดเมื่อ Wrap ขึ้นบรรทัดใหม่
                    children: _selectedGenres
                        .map((genre) => Chip(label: Text(genre)))
                        .toList(),
                  ),
                ],
                if (_selectionError != null) ...[
                  const SizedBox(height: 8), // เว้นระยะห่างแนวตั้ง 8 พิกเซล
                  Text(
                    _selectionError!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.error,
                    ),
                  ),
                ],
                const SizedBox(height: 20), // เว้นระยะห่างแนวตั้ง 20 พิกเซล
                Divider(color: colors.outlineVariant),
                const SizedBox(height: 16), // เว้นระยะห่างแนวตั้ง 16 พิกเซล
                Text(
                  'สถานะเรื่อง',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12), // เว้นระยะห่างแนวตั้ง 12 พิกเซล
                DropdownButtonFormField<String>(
                  value: _status, // สถานะ Private/Public ที่เลือกอยู่ในฟอร์ม
                  decoration: InputDecoration( // กำหนดข้อความและรูปแบบขอบของช่องกรอก
                    labelText: 'Visibility', // ข้อความชื่อช่องที่แสดงในฟอร์ม
                    prefixIcon: const Icon(Icons.visibility_outlined), // ไอคอนด้านหน้าของช่องกรอก
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
                  onChanged: (value) { // ทำงานทันทีเมื่อค่าช่องหรือรายการเลือกเปลี่ยน
                    if (value != null) setState(() => _status = value);
                  },
                ),
                const SizedBox(height: 14), // เว้นระยะห่างแนวตั้ง 14 พิกเซล
                DropdownButtonFormField<String>(
                  value: _releaseStatus, // สถานะการออกตอนที่เลือกอยู่
                  decoration: InputDecoration( // กำหนดข้อความและรูปแบบขอบของช่องกรอก
                    labelText: 'Release status', // ข้อความชื่อช่องที่แสดงในฟอร์ม
                    prefixIcon: const Icon(Icons.schedule_rounded), // ไอคอนด้านหน้าของช่องกรอก
                    filled: true,
                    fillColor: colors.surfaceContainerLow,
                    border: fieldBorder,
                    enabledBorder: fieldBorder,
                    focusedBorder: focusedBorder,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: 'ongoing', // รหัสที่จะส่ง API เมื่อเลือก Ongoing
                      child: Text('Ongoing'),
                    ),
                    const DropdownMenuItem(
                      value: 'coming_soon', // รหัสที่จะส่ง API เมื่อเลือก Coming Soon
                      child: Text('Coming Soon'),
                    ),
                    if (widget.manga != null) ...const [
                      DropdownMenuItem(value: 'hiatus', child: Text('Hiatus')),
                      DropdownMenuItem(
                        value: 'completed', // รหัสที่จะส่ง API เมื่อเลือก Completed
                        child: Text('Completed'),
                      ),
                    ],
                  ],
                  onChanged: (value) { // ทำงานทันทีเมื่อค่าช่องหรือรายการเลือกเปลี่ยน
                    if (value != null) setState(() => _releaseStatus = value);
                  },
                ),
                const SizedBox(height: 20), // เว้นระยะห่างแนวตั้ง 20 พิกเซล
                Divider(color: colors.outlineVariant),
                const SizedBox(height: 16), // เว้นระยะห่างแนวตั้ง 16 พิกเซล
                Text(
                  'ภาพปกและรายละเอียด',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8), // เว้นระยะห่างแนวตั้ง 8 พิกเซล
                Text('JPG, PNG, WebP · ไม่เกิน 5 MB', style: helperStyle),
                const SizedBox(height: 12), // เว้นระยะห่างแนวตั้ง 12 พิกเซล
                OutlinedButton.icon(
                  onPressed: _chooseCover, // เรียก callback นี้เมื่อผู้ใช้กดปุ่ม
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('เลือกภาพปก'),
                ),
                if (_coverFile != null) ...[
                  const SizedBox(height: 10), // เว้นระยะห่างแนวตั้ง 10 พิกเซล
                  Container(
                    width: double.infinity, // ความกว้างของพื้นที่แสดงหรือรูปภาพ
                    padding: const EdgeInsets.all(14), // ระยะว่างด้านในระหว่างขอบกับเนื้อหา
                    decoration: BoxDecoration( // กำหนดสี ขอบ หรือเงาของกล่องนี้
                      color: colors.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14), // ความโค้งของมุมกรอบ
                    ),
                    child: Text(
                      _coverFile!.name,
                      maxLines: 2, // แสดงชื่อไฟล์สูงสุดสองบรรทัดก่อนตัดด้วย ...
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                if (_coverError != null) ...[
                  const SizedBox(height: 8), // เว้นระยะห่างแนวตั้ง 8 พิกเซล
                  Text(
                    _coverError!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.error,
                    ),
                  ),
                ],
                const SizedBox(height: 14), // เว้นระยะห่างแนวตั้ง 14 พิกเซล
                TextField(
                  controller: _descriptionController, // เก็บคำอธิบาย Manga
                  minLines: 2, // จำนวนบรรทัดขั้นต่ำของช่องข้อความ
                  maxLines: 4, // จำนวนบรรทัดสูงสุดของช่องข้อความ
                  style: theme.textTheme.bodyLarge,
                  decoration: InputDecoration( // กำหนดข้อความและรูปแบบขอบของช่องกรอก
                    labelText: 'รายละเอียด', // ข้อความชื่อช่องที่แสดงในฟอร์ม
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor: colors.surfaceContainerLow,
                    border: fieldBorder,
                    enabledBorder: fieldBorder,
                    focusedBorder: focusedBorder,
                  ),
                ),
                const SizedBox(height: 14), // เว้นระยะห่างแนวตั้ง 14 พิกเซล
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
          onPressed: () => Navigator.pop(context), // ปิดหน้าหรือ dialog และส่งผลกลับ
          child: const Text(
            'ยกเลิก',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        FilledButton.icon(
          onPressed: _submit, // เรียก callback นี้เมื่อผู้ใช้กดปุ่ม
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

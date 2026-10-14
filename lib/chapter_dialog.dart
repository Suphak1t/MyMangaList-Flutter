import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

/// ข้อมูลที่หน้าจัดการตอนจะใช้สร้าง/แก้ตอนและอัปโหลดไฟล์
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

/// ฟอร์มเพิ่มหรือแก้ไขตอน; nextNumber เสนอเลขตอนใหม่โดยอัตโนมัติ
class ChapterDialog extends StatefulWidget {
  const ChapterDialog({super.key, required this.nextNumber, this.chapter});

  final int nextNumber;
  final Map<String, dynamic>? chapter;

  @override
  State<ChapterDialog> createState() => _ChapterDialogState();
}

class _ChapterDialogState extends State<ChapterDialog> {
  // State เก็บเลขตอน ชื่อตอน สถานะเผยแพร่ ประเภทเนื้อหา และไฟล์
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
    // เมื่อแก้ไขตอน ให้นำเลข ชื่อ และการเผยแพร่เดิมมาใส่ในฟอร์ม
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

  // เลือก PDF หนึ่งไฟล์หรือภาพหลายไฟล์ แล้วตรวจจำนวน ชื่อซ้ำ และขนาด
  Future<void> _pickFiles(String type) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom, // ใช้ชุดนามสกุลไฟล์ที่ระบุเอง
      allowedExtensions: type == 'pdf'
          ? ['pdf']
          : ['jpg', 'jpeg', 'png', 'webp'],
      allowMultiple: type == 'images', // อนุญาตเลือกหลายไฟล์สำหรับชุดภาพ
      withData: false, // ไม่โหลด bytes ทั้งไฟล์เข้าหน่วยความจำตอนเลือก
    );
    if (picked == null || picked.files.isEmpty || !mounted) return;
    // การเพิ่มภาพรอบถัดไปรวมกับภาพเดิมและเรียงตามชื่อไฟล์
    final files = [
      if (type == 'images' && _contentType == 'images') ..._files,
      ...picked.files,
    ]..sort((a, b) => a.name.compareTo(b.name));
    final maxFileSize = (type == 'pdf' ? 20 : 5) * 1024 * 1024;
    final totalSize = files.fold<int>(0, (total, file) => total + file.size);
    final names = files.map((file) => file.name.toLowerCase()).toSet();
    // รวมเงื่อนไขตรวจไฟล์เพื่อแสดงเหตุผลเดียวที่ต้องแก้ก่อนบันทึก
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

  // นำไฟล์ที่ไม่ต้องการออกจากชุดที่เลือกก่อนอัปโหลด
  void _removeFile(int index) {
    setState(() {
      _files.removeAt(index);
      if (_files.isEmpty) _contentType = null;
      _fileError = null;
    });
  }

  // ตอนใหม่ต้องมีไฟล์; ตอนเดิมแก้ข้อมูลได้โดยไม่ต้องเลือกไฟล์ใหม่
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
      borderRadius: BorderRadius.circular(14), // ความโค้งของมุมกรอบ
      borderSide: BorderSide.none,
    );
    final fieldStyle = theme.textTheme.bodyLarge;
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
                    widget.chapter == null ? 'เพิ่มตอน' : 'แก้ไขตอน',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4), // เว้นระยะห่างแนวตั้ง 4 พิกเซล
                  Text(
                    'รายละเอียดและไฟล์ของตอน',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8), // เว้นระยะห่างแนวนอน 8 พิกเซล
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
        width: 460, // ความกว้างของพื้นที่แสดงหรือรูปภาพ
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min, // กำหนดให้ Row หรือ Column ใช้พื้นที่ตามเนื้อหาหรือเต็มแกน
              crossAxisAlignment: CrossAxisAlignment.start, // จัดแนวลูกตามแกนขวางของ Row หรือ Column
              children: [
                Text(
                  'ข้อมูลตอน',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12), // เว้นระยะห่างแนวตั้ง 12 พิกเซล
                TextFormField(
                  controller: _number, // เก็บเลขตอนที่กรอก
                  keyboardType: TextInputType.number, // เลือกชนิดแป้นพิมพ์ให้เหมาะกับข้อมูล
                  style: fieldStyle,
                  decoration: InputDecoration( // กำหนดข้อความและรูปแบบขอบของช่องกรอก
                    labelText: 'เลขตอน *', // ข้อความชื่อช่องที่แสดงในฟอร์ม
                    prefixIcon: const Icon(Icons.format_list_numbered_rounded), // ไอคอนด้านหน้าของช่องกรอก
                    filled: true,
                    fillColor: colors.surfaceContainerLow,
                    border: fieldBorder,
                    enabledBorder: fieldBorder,
                    focusedBorder: fieldBorder.copyWith(
                      borderSide: BorderSide(color: colors.primary, width: 1.5),
                    ),
                  ),
                  validator: (value) { // ตรวจค่าที่กรอกและคืนข้อความผิดพลาดเมื่อไม่ผ่าน
                    final number = int.tryParse(value?.trim() ?? '');
                    return number == null || number < 1
                        ? 'กรุณากรอกเลขตอนตั้งแต่ 1'
                        : null;
                  },
                ),
                const SizedBox(height: 14), // เว้นระยะห่างแนวตั้ง 14 พิกเซล
                TextFormField(
                  controller: _title, // เก็บชื่อตอนที่กรอก
                  maxLength: 255, // จำกัดจำนวนตัวอักษรที่พิมพ์ได้
                  style: fieldStyle,
                  decoration: InputDecoration( // กำหนดข้อความและรูปแบบขอบของช่องกรอก
                    labelText: 'ชื่อตอน (ไม่บังคับ)', // ข้อความชื่อช่องที่แสดงในฟอร์ม
                    prefixIcon: const Icon(Icons.title_rounded), // ไอคอนด้านหน้าของช่องกรอก
                    filled: true,
                    fillColor: colors.surfaceContainerLow,
                    border: fieldBorder,
                    enabledBorder: fieldBorder,
                    focusedBorder: fieldBorder.copyWith(
                      borderSide: BorderSide(color: colors.primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 4), // เว้นระยะห่างแนวตั้ง 4 พิกเซล
                Material(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14), // ความโค้งของมุมกรอบ
                  child: SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14), // ระยะว่างภายในส่วนเนื้อหาของ widget
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
                    value: _published, // เปิดสวิตช์เมื่อกำหนดให้เผยแพร่ตอนนี้
                    onChanged: (value) => setState(() => _published = value), // ทำงานทันทีเมื่อค่าช่องหรือรายการเลือกเปลี่ยน
                  ),
                ),
                const SizedBox(height: 24), // เว้นระยะห่างแนวตั้ง 24 พิกเซล
                Divider(color: colors.outlineVariant),
                const SizedBox(height: 16), // เว้นระยะห่างแนวตั้ง 16 พิกเซล
                Text(
                  'ไฟล์ของตอน',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12), // เว้นระยะห่างแนวตั้ง 12 พิกเซล
                Container(
                  width: double.infinity, // ความกว้างของพื้นที่แสดงหรือรูปภาพ
                  padding: const EdgeInsets.all(14), // ระยะว่างด้านในระหว่างขอบกับเนื้อหา
                  decoration: BoxDecoration( // กำหนดสี ขอบ หรือเงาของกล่องนี้
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14), // ความโค้งของมุมกรอบ
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, // จัดแนวลูกตามแกนขวางของ Row หรือ Column
                    children: [
                      Text('PDF 1 ไฟล์ ไม่เกิน 20 MB', style: helperStyle),
                      const SizedBox(height: 4), // เว้นระยะห่างแนวตั้ง 4 พิกเซล
                      Text(
                        'หรือภาพ JPG, PNG, WebP สูงสุด 15 ไฟล์ต่อตอน เลือกเพิ่มได้หลายรอบ (ไม่เกิน 5 MB ต่อภาพ และรวมไม่เกิน 30 MB)',
                        style: helperStyle,
                      ),
                      const SizedBox(height: 4), // เว้นระยะห่างแนวตั้ง 4 พิกเซล
                      Text(
                        'ตั้งชื่อภาพตามลำดับ เช่น 001.png, 002.png',
                        style: helperStyle,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16), // เว้นระยะห่างแนวตั้ง 16 พิกเซล
                Wrap(
                  spacing: 8, // ระยะห่างระหว่าง widget ที่อยู่บรรทัดเดียวกัน
                  runSpacing: 8, // ระยะห่างระหว่างบรรทัดเมื่อ Wrap ขึ้นบรรทัดใหม่
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _pickFiles('pdf'), // เรียก callback นี้เมื่อผู้ใช้กดปุ่ม
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
                  const SizedBox(height: 14), // เว้นระยะห่างแนวตั้ง 14 พิกเซล
                  Container(
                    width: double.infinity, // ความกว้างของพื้นที่แสดงหรือรูปภาพ
                    padding: const EdgeInsets.all(14), // ระยะว่างด้านในระหว่างขอบกับเนื้อหา
                    decoration: BoxDecoration( // กำหนดสี ขอบ หรือเงาของกล่องนี้
                      color: colors.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14), // ความโค้งของมุมกรอบ
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, // จัดแนวลูกตามแกนขวางของ Row หรือ Column
                      children: [
                        Text(
                          _contentType == 'images'
                              ? 'ภาพที่เลือก ${_files.length}/15 ไฟล์'
                              : 'PDF ที่เลือก',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8), // เว้นระยะห่างแนวตั้ง 8 พิกเซล
                        Wrap(
                          spacing: 6, // ระยะห่างระหว่าง widget ที่อยู่บรรทัดเดียวกัน
                          runSpacing: 6, // ระยะห่างระหว่างบรรทัดเมื่อ Wrap ขึ้นบรรทัดใหม่
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
                                onDeleted: () => _removeFile(index), // ลบชิปตัวกรองนี้เมื่อกดเครื่องหมายปิด
                                deleteButtonTooltipMessage: 'ลบภาพที่เลือก',
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                if (widget.chapter != null && _files.isEmpty) ...[
                  const SizedBox(height: 12), // เว้นระยะห่างแนวตั้ง 12 พิกเซล
                  Text('ไม่เลือกไฟล์ใหม่ = ใช้ไฟล์เดิม', style: helperStyle),
                ],
                if (_fileError != null) ...[
                  const SizedBox(height: 10), // เว้นระยะห่างแนวตั้ง 10 พิกเซล
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
          onPressed: () => Navigator.pop(context), // ปิดหน้าหรือ dialog และส่งผลกลับ
          child: const Text(
            'ยกเลิก',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        FilledButton.icon(
          onPressed: _submit, // เรียก callback นี้เมื่อผู้ใช้กดปุ่ม
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

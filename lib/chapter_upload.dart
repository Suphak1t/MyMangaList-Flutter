import 'dart:convert';

import 'package:http/http.dart' as http;

import 'chapter_dialog.dart';
import 'config.dart';

/// อัปโหลดไฟล์ของตอนหลังสร้าง chapter_id แล้ว โดยใช้ multipart
Future<void> uploadChapterFiles(
  int chapterId,
  ChapterFormResult result,
  String accessToken,
) async {
  // หากแก้เฉพาะข้อมูลตอน ไม่ส่งคำขออัปโหลดไฟล์
  if (result.files.isEmpty) return;
  final request = http.MultipartRequest(
    'POST',
    Uri.parse('${ApiConfig.baseUrl}/chapter_upload.php'),
  );
  request.headers['Authorization'] = 'Bearer $accessToken';
  request.fields['chapter_id'] = '$chapterId';
  request.fields['content_type'] = result.contentType!;
  // PDF ใช้ field pdf; ชุดภาพใช้ pages[] เพื่อให้ PHP รับหลายหน้า
  for (final file in result.files) {
    request.files.add(
      await http.MultipartFile.fromPath(
        result.contentType == 'pdf' ? 'pdf' : 'pages[]',
        file.path!,
      ),
    );
  }
  final response = await http.Response.fromStream(await request.send());
  final data = jsonDecode(response.body) as Map<String, dynamic>;
  // ส่งข้อผิดพลาดจาก API กลับให้หน้าที่เรียกไปแสดงแก่ผู้ใช้
  if (response.statusCode != 200 || data['success'] != true) {
    throw Exception(data['message'] ?? 'อัปโหลดไฟล์ไม่สำเร็จ');
  }
}

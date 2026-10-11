import 'dart:convert';

import 'package:http/http.dart' as http;

import 'chapter_dialog.dart';
import 'config.dart';

Future<void> uploadChapterFiles(
  int chapterId,
  ChapterFormResult result,
  String accessToken,
) async {
  if (result.files.isEmpty) return;
  final request = http.MultipartRequest(
    'POST',
    Uri.parse('${ApiConfig.baseUrl}/chapter_upload.php'),
  );
  request.headers['Authorization'] = 'Bearer $accessToken';
  request.fields['chapter_id'] = '$chapterId';
  request.fields['content_type'] = result.contentType!;
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
  if (response.statusCode != 200 || data['success'] != true) {
    throw Exception(data['message'] ?? 'อัปโหลดไฟล์ไม่สำเร็จ');
  }
}

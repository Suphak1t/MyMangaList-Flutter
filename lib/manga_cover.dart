import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'config.dart';

/// แสดงภาพปกผ่าน API ที่ต้องใช้ token และใช้ภาพแทนเมื่อยังไม่มีปก
class MangaCover extends StatelessWidget {
  const MangaCover({
    super.key,
    required this.manga,
    required this.accessToken,
    this.width = 92,
    this.height = 124,
  });

  final Map<String, dynamic> manga;
  final String accessToken;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    // ชื่อไฟล์ใช้เป็นค่า version ใน URL เพื่อให้ภาพเปลี่ยนทันทีหลังอัปโหลดใหม่
    final filename = manga['cover_filename'];
    final placeholder = Container(
      width: width, // ความกว้างของพื้นที่แสดงหรือรูปภาพ
      height: height, // ความสูงของพื้นที่แสดงหรือรูปภาพ
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.auto_stories_outlined, size: 36),
    );
    // เรื่องที่ไม่มีปกไม่ต้องเรียก API และแสดง placeholder แทน
    if (filename == null || filename.toString().isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8), // ความโค้งของมุมกรอบ
      child: Image.network(
        '${ApiConfig.baseUrl}/manga_cover.php?manga_id=${manga['manga_id']}&v=$filename',
        headers: {'Authorization': 'Bearer $accessToken'}, // ส่ง HTTP headers เช่น Bearer token ไปกับคำขอ
        width: width, // ความกว้างของพื้นที่แสดงหรือรูปภาพ
        height: height, // ความสูงของพื้นที่แสดงหรือรูปภาพ
        fit: BoxFit.cover, // วิธีปรับภาพให้พอดีกับพื้นที่แสดง
        errorBuilder: (context, error, stackTrace) => placeholder,
      ),
    );
  }
}

/// ส่งภาพปกแบบ multipart หลังมี manga_id แล้ว และคืนชื่อไฟล์ใหม่จาก API
Future<String> uploadMangaCover(
  int mangaId,
  PlatformFile file,
  String accessToken,
) async {
  final request = http.MultipartRequest(
    'POST',
    Uri.parse('${ApiConfig.baseUrl}/manga_cover_upload.php'),
  );
  // ส่ง Bearer token เพื่อให้ server ตรวจเจ้าของ Manga ก่อนรับไฟล์
  request.headers['Authorization'] = 'Bearer $accessToken';
  request.fields['manga_id'] = '$mangaId';
  request.files.add(await http.MultipartFile.fromPath('cover', file.path!));
  final response = await http.Response.fromStream(await request.send());
  final data = jsonDecode(response.body) as Map<String, dynamic>;
  if (response.statusCode != 200 || data['success'] != true) {
    throw Exception(data['message'] ?? 'อัปโหลดภาพปกไม่สำเร็จ');
  }
  return data['cover_filename'].toString();
}

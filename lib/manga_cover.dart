import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'config.dart';

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
    final filename = manga['cover_filename'];
    final placeholder = Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.auto_stories_outlined, size: 36),
    );
    if (filename == null || filename.toString().isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        '${ApiConfig.baseUrl}/manga_cover.php?manga_id=${manga['manga_id']}&v=$filename',
        headers: {'Authorization': 'Bearer $accessToken'},
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => placeholder,
      ),
    );
  }
}

Future<String> uploadMangaCover(
  int mangaId,
  PlatformFile file,
  String accessToken,
) async {
  final request = http.MultipartRequest(
    'POST',
    Uri.parse('${ApiConfig.baseUrl}/manga_cover_upload.php'),
  );
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

import 'package:flutter/material.dart';

import 'manga_cover.dart';

/// แปลง release_status จากฐานข้อมูลเป็นชื่อสถานะภาษาอังกฤษที่แสดงบนจอ
String mangaReleaseLabel(Object? value) => switch (value) {
  'coming_soon' => 'Coming Soon',
  'hiatus' => 'Hiatus',
  'completed' => 'Completed',
  _ => 'Ongoing',
};

/// แปลง private/public เป็นข้อความที่ผู้อ่านเห็นบนการ์ด
String mangaVisibilityLabel(Object? value) =>
    value == 'public' ? 'Public' : 'Private';

/// การ์ด Manga ที่ใช้ร่วมกันใน Dashboard และหน้าค้นหา
class MangaCard extends StatelessWidget {
  const MangaCard({
    super.key,
    required this.manga,
    required this.accessToken,
    required this.onTap,
  });

  final Map<String, dynamic> manga;
  final String accessToken;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // แสดงหลายแนวจาก genres[]; รองรับข้อมูลเก่าที่มี genre ช่องเดียว
    final genres = manga['genres'] is List
        ? (manga['genres'] as List).join(', ')
        : (manga['genre'] ?? '').toString();
    // แสดงคะแนนเฉลี่ยหนึ่งตำแหน่งและใช้ 0.0 หากยังไม่มีคะแนน
    final rating =
        (manga['rating_average'] as num?)?.toStringAsFixed(1) ?? '0.0';
    return Card(
      margin: const EdgeInsets.only(bottom: 10), // ระยะว่างด้านนอกระหว่าง widget กับบริเวณรอบข้าง
      // แตะได้ทั้งการ์ด โดย onTap มาจากหน้าที่เรียก MangaCard
      child: InkWell(
        borderRadius: BorderRadius.circular(12), // ความโค้งของมุมกรอบ
        onTap: onTap, // ทำงานเมื่อแตะการ์ดหรือรายการนี้
        child: Padding(
          padding: const EdgeInsets.all(10), // ระยะว่างด้านในระหว่างขอบกับเนื้อหา
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start, // จัดแนวลูกตามแกนขวางของ Row หรือ Column
            children: [
              MangaCover(manga: manga, accessToken: accessToken),
              const SizedBox(width: 12), // เว้นระยะห่างแนวนอน 12 พิกเซล
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, // จัดแนวลูกตามแกนขวางของ Row หรือ Column
                  children: [
                    Text(
                      (manga['title'] ?? '').toString(),
                      maxLines: 2, // จำกัดชื่อเรื่องที่แสดงไม่เกินสองบรรทัด
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4), // เว้นระยะห่างแนวตั้ง 4 พิกเซล
                    Text('ผู้แต่ง: ${manga['author'] ?? '—'}'),
                    if (genres.isNotEmpty)
                      Text(
                        genres,
                        maxLines: 1, // แสดงแนวเรื่องเพียงบรรทัดเดียว
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      '${manga['chapter_count'] ?? 0} ตอน · ${mangaReleaseLabel(manga['release_status'])}',
                    ),
                    Text(
                      '${manga['is_hidden'] == true ? 'Hidden' : mangaVisibilityLabel(manga['status'])} · '
                      'ผู้อ่าน ${manga['view_count'] ?? 0} · ★ $rating (${manga['rating_count'] ?? 0})',
                      maxLines: 2, // จำกัดข้อมูลสรุปที่แสดงไม่เกินสองบรรทัด
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

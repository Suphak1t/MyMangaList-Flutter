import 'package:flutter/material.dart';

import 'manga_cover.dart';

String mangaReleaseLabel(Object? value) => switch (value) {
  'coming_soon' => 'Coming Soon',
  'hiatus' => 'Hiatus',
  'completed' => 'Completed',
  _ => 'Ongoing',
};

String mangaVisibilityLabel(Object? value) =>
    value == 'public' ? 'Public' : 'Private';

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
    final genres = manga['genres'] is List
        ? (manga['genres'] as List).join(', ')
        : (manga['genre'] ?? '').toString();
    final rating =
        (manga['rating_average'] as num?)?.toStringAsFixed(1) ?? '0.0';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MangaCover(manga: manga, accessToken: accessToken),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (manga['title'] ?? '').toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text('ผู้แต่ง: ${manga['author'] ?? '—'}'),
                    if (genres.isNotEmpty)
                      Text(
                        genres,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      '${manga['chapter_count'] ?? 0} ตอน · ${mangaReleaseLabel(manga['release_status'])}',
                    ),
                    Text(
                      '${manga['is_hidden'] == true ? 'Hidden' : mangaVisibilityLabel(manga['status'])} · '
                      'ผู้อ่าน ${manga['view_count'] ?? 0} · ★ $rating (${manga['rating_count'] ?? 0})',
                      maxLines: 2,
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

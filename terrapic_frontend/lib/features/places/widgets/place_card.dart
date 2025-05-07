/// TerraPicアプリの場所カードウィジェット
///
/// 場所の情報をカード形式で表示するウィジェット。
/// 検索結果やリスト表示で使用される。
///
/// 主な機能:
/// - 場所の基本情報表示
/// - サムネイル画像の表示
/// - 投稿数と評価の表示
/// - タップによる詳細画面への遷移
///
import 'package:flutter/material.dart';

class PlaceCard extends StatelessWidget {
  final Map<String, dynamic> place;
  final VoidCallback? onTap;

  const PlaceCard({
    Key? key,
    required this.place,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // サムネイル画像
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child:
                    place['top_image'] != null || place['latest_image'] != null
                        ? Image.network(
                            place['top_image'] ?? place['latest_image'],
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              print('Error loading image: $error');
                              return Container(
                                width: 100,
                                height: 100,
                                color: Colors.grey[200],
                                child: const Icon(Icons.error),
                              );
                            },
                          )
                        : Container(
                            width: 100,
                            height: 100,
                            color: Colors.grey[200],
                            child: const Icon(Icons.place),
                          ),
              ),
              const SizedBox(width: 12),

              // 場所の情報
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 場所の名前
                    Text(
                      place['name'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // 統計情報
                    Row(
                      children: [
                        // 投稿数
                        Row(
                          children: [
                            const Icon(Icons.photo_library, size: 16),
                            const SizedBox(width: 4),
                            Text('${place['post_count'] ?? 0}'),
                          ],
                        ),
                        const SizedBox(width: 16),

                        // 評価
                        if (place['rating'] != null) ...[
                          Row(
                            children: [
                              const Icon(Icons.star,
                                  size: 16, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text(
                                place['rating'].toStringAsFixed(1),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                        ],

                        // お気に入り数
                        Row(
                          children: [
                            const Icon(Icons.bookmark,
                                size: 16, color: Colors.blue),
                            const SizedBox(width: 4),
                            Text('${place['favorite_count'] ?? 0}'),
                          ],
                        ),
                      ],
                    ),

                    if (place['formatted_address'] != null) ...[
                      const SizedBox(height: 8),
                      // 住所
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 16),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              place['formatted_address'],
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
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

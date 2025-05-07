/// TerraPicアプリのカスタム情報ウィンドウ
///
/// 地図上のマーカーをタップした際に表示される
/// 詳細情報ウィンドウを提供する。
///
/// 主な機能:
/// - 場所の基本情報表示
/// - サムネイル画像の表示
/// - 評価やお気に入り数の表示
/// - タップによる詳細画面への遷移
import 'package:flutter/material.dart';

class CustomInfoWindow extends StatelessWidget {
  // 場所の名前
  final String name;

  // 画像のURL
  final String imageUrl;

  // お気に入り数（String型も受け入れられるように dynamic型で定義）
  final dynamic favoriteCount;

  // 評価（String型で受け取る）
  final String rating;

  const CustomInfoWindow({
    Key? key,
    required this.name,
    required this.imageUrl,
    required this.favoriteCount,
    required this.rating,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // お気に入り数を数値として処理
    final int numericFavoriteCount = _parseCount(favoriteCount);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー（場所名）
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // 画像
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            child: Image.network(
              imageUrl,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 180,
                  color: Colors.grey[200],
                  child: const Center(
                    child: Icon(
                      Icons.error_outline,
                      color: Colors.grey,
                      size: 32,
                    ),
                  ),
                );
              },
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  height: 180,
                  color: Colors.grey[200],
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              },
            ),
          ),

          // フッター（評価とお気に入り数）
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 評価
                Row(
                  children: [
                    const Icon(
                      Icons.star,
                      color: Colors.amber,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      rating,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                // お気に入り数
                Row(
                  children: [
                    const Icon(
                      Icons.favorite,
                      color: Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      numericFavoriteCount.toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // タップのヒント
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: const Text(
              'タップして詳細を表示',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// お気に入り数を数値として解析
  int _parseCount(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.round();
    return 0;
  }
}

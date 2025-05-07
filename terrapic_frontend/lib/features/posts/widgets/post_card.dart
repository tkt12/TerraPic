/// TerraPicアプリの投稿カードウィジェット
///
/// 投稿の情報をカード形式で表示するウィジェット。
/// 画像、ユーザー情報、いいねなどの情報を含む。
///
/// 主な機能:
/// - 投稿画像の表示
/// - ユーザー情報の表示
/// - いいねの表示と操作
/// - 場所情報の表示
/// - 詳細画面への遷移
///
import 'package:flutter/material.dart';
import '../../../shared/utils/date_formatter.dart';

class PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final Function(Map<String, dynamic>)? onUserTap;
  final Function(Map<String, dynamic>)? onPlaceTap;
  final Function(Map<String, dynamic>)? onLikeTap;
  final Function(Map<String, dynamic>)? onTap;

  const PostCard({
    Key? key,
    required this.post,
    this.onUserTap,
    this.onPlaceTap,
    this.onLikeTap,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ユーザー情報ヘッダー
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            leading: GestureDetector(
              onTap: () => onUserTap?.call(post),
              child: CircleAvatar(
                backgroundImage: post['user']?['profile_image'] != null
                    ? NetworkImage(post['user']['profile_image'])
                    : null,
                child: post['user']?['profile_image'] == null
                    ? const Icon(Icons.person)
                    : null,
              ),
            ),
            title: GestureDetector(
              onTap: () => onUserTap?.call(post),
              child: Text(
                post['user']?['username'] ?? '不明なユーザー',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            subtitle: GestureDetector(
              onTap: () => onPlaceTap?.call(post),
              child: Row(
                children: [
                  const Icon(Icons.place, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      post['displayed_place_name'] ?? '不明な場所',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.more_horiz),
              onPressed: () {
                // TODO: 投稿のメニューを表示
              },
            ),
          ),

          // 投稿画像
          GestureDetector(
            onTap: () => onTap?.call(post),
            child: Container(
              constraints: const BoxConstraints(
                maxHeight: 400,
              ),
              width: double.infinity,
              child: Image.network(
                post['photo_image'],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 300,
                    color: Colors.grey[200],
                    child: const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.grey,
                    ),
                  );
                },
              ),
            ),
          ),

          // アクションボタンとカウンター
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // いいねボタン
                IconButton(
                  icon: Icon(
                    post['is_liked'] ?? false
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: post['is_liked'] ?? false ? Colors.red : null,
                  ),
                  onPressed: () => onLikeTap?.call(post),
                ),
                Text(
                  '${post['like_count'] ?? 0}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),

                // 撮影時期
                if (post['weather'] != null) ...[
                  Text(
                    post['weather'],
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 8),
                ],
                if (post['season'] != null) ...[
                  Text(
                    post['season'],
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),

          // 説明文
          if (post['description'] != null && post['description'].isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(post['description']),
            ),

          // 投稿日時
          if (post['created_at'] != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(
                DateFormatter.formatDateTime(
                    DateTime.parse(post['created_at'])),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

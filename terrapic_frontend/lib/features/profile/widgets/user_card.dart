/// TerraPicアプリのユーザーカードウィジェット
///
/// ユーザーの基本情報をカード形式で表示する。
/// 検索結果やフォロー/フォロワーリストで使用される。
///
/// 主な機能:
/// - ユーザーのプロフィール画像表示
/// - ユーザー名と表示名の表示
/// - フォロー状態の表示と操作
/// - 投稿数やフォロワー数の表示
///
import 'package:flutter/material.dart';

class UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool isFollowing;
  final bool isCurrentUser;
  final Function()? onUserTap;
  final Function()? onFollowTap;

  const UserCard({
    Key? key,
    required this.user,
    this.isFollowing = false,
    this.isCurrentUser = false,
    this.onUserTap,
    this.onFollowTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: onUserTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // プロフィール画像
              CircleAvatar(
                radius: 30,
                backgroundImage: user['profile_image'] != null
                    ? NetworkImage(user['profile_image'])
                    : null,
                child: user['profile_image'] == null
                    ? const Icon(Icons.person, size: 30)
                    : null,
              ),
              const SizedBox(width: 16),

              // ユーザー情報
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ユーザー名
                    Text(
                      '@${user['username']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (user['name'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        user['name'],
                        style: const TextStyle(
                          color: Colors.black87,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),

                    // 統計情報
                    Row(
                      children: [
                        // 投稿数
                        Row(
                          children: [
                            const Icon(Icons.photo_library, size: 16),
                            const SizedBox(width: 4),
                            Text('${user['post_count'] ?? 0}'),
                          ],
                        ),
                        const SizedBox(width: 16),

                        // フォロワー数
                        Row(
                          children: [
                            const Icon(Icons.people, size: 16),
                            const SizedBox(width: 4),
                            Text('${user['follower_count'] ?? 0}'),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // フォローボタン（自分以外のユーザーの場合のみ表示）
              if (!isCurrentUser && onFollowTap != null)
                TextButton(
                  onPressed: onFollowTap,
                  style: TextButton.styleFrom(
                    backgroundColor:
                        isFollowing ? Colors.grey[200] : Colors.blue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    isFollowing ? 'フォロー中' : 'フォローする',
                    style: TextStyle(
                      color: isFollowing ? Colors.black87 : Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// TerraPicアプリのプロフィールヘッダー
///
/// プロフィール画面上部に表示されるヘッダーコンポーネント。
/// ユーザー情報、統計、アクションボタンを表示する。
///
/// 主な機能:
/// - プロフィール画像の表示
/// - ユーザー情報の表示
/// - フォロー/編集ボタン
/// - 投稿数などの統計表示
///
import 'package:flutter/material.dart';
import '../models/profile.dart';
import '../../../core/config/app_config.dart';
import '../../profile/screens/follow_followers_screen.dart';

class ProfileHeader extends StatelessWidget {
  final Profile profile;
  final bool isOwnProfile;
  final bool isFollowing;
  final VoidCallback? onEditPressed;
  final VoidCallback? onFollowPressed;

  const ProfileHeader({
    Key? key,
    required this.profile,
    required this.isOwnProfile,
    this.isFollowing = false,
    this.onEditPressed,
    this.onFollowPressed,
  }) : super(key: key);

  /// 画像URLを完全なURLに変換
  String _getFullImageUrl(String? partialUrl) {
    if (partialUrl == null || partialUrl.isEmpty) return '';
    if (partialUrl.startsWith('http://') || partialUrl.startsWith('https://')) {
      return partialUrl;
    }
    return '${AppConfig.backendUrl}$partialUrl';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: <Widget>[
              // プロフィール画像
              CircleAvatar(
                radius: 40,
                backgroundImage: profile.profileImage != null
                    ? NetworkImage(_getFullImageUrl(profile.profileImage))
                    : null,
                child: profile.profileImage == null
                    ? const Icon(Icons.person, size: 40)
                    : null,
              ),
              const SizedBox(width: 16),

              // プロフィール情報
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text('@${profile.username}'),
                    if (profile.bio != null && profile.bio!.isNotEmpty)
                      Text(
                        profile.bio!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),

              // アクションボタン（編集/フォロー）
              if (isOwnProfile)
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.grey),
                  onPressed: onEditPressed,
                )
              else if (!isOwnProfile)
                SizedBox(
                  width: 135,
                  child: ElevatedButton(
                    onPressed: onFollowPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFollowing ? Colors.grey : Colors.blue,
                      foregroundColor: Colors.white, // テキスト色を白に設定
                    ),
                    child: Text(isFollowing ? 'フォロー中' : 'フォローする'),
                  ),
                ),
            ],
          ),
        ),

        // 統計情報
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat(
                context,
                'フォロー',
                profile.followedCount,
                () => _navigateToFollowList(context, false),
              ),
              _buildStat(
                context,
                'フォロワー',
                profile.followerCount,
                () => _navigateToFollowList(context, true),
              ),
              _buildStat(
                context,
                'いいね',
                profile.totalLikes,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  /// 統計情報の項目を構築
  Widget _buildStat(BuildContext context, String label, int value,
      [VoidCallback? onTap]) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 80,
        child: Column(
          children: [
            Text(
              value.toString(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: onTap != null ? Colors.blue : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// フォロー/フォロワー一覧画面に遷移
  void _navigateToFollowList(BuildContext context, bool isFollowers) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FollowListScreen(
          userId: profile.id,
          title: isFollowers ? 'フォロワー' : 'フォロー',
          isFollowers: isFollowers,
        ),
      ),
    );
  }
}

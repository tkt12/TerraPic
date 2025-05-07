/// TerraPicアプリのプロフィールモデル
///
/// ユーザーのプロフィール情報を管理するモデル。
/// プロフィール情報の構造化とバリデーションを提供する。
///
/// 主な機能:
/// - プロフィール情報の構造化
/// - JSONシリアライズ/デシリアライズ
/// - バリデーション
/// - プロフィール情報の更新
///
class Profile {
  final String id;
  final String username;
  final String name;
  final String? bio;
  final String? profileImage;
  final int postCount;
  final int followerCount;
  final int followedCount;
  final int totalLikes;
  final bool isFollowing;

  Profile({
    required this.id,
    required this.username,
    required this.name,
    this.bio,
    this.profileImage,
    this.postCount = 0,
    this.followerCount = 0,
    this.followedCount = 0,
    this.totalLikes = 0,
    this.isFollowing = false,
  });

  /// JSONからProfileオブジェクトを生成
  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'].toString(),
      username: json['username'],
      name: json['name'] ?? '',
      bio: json['bio'],
      profileImage: json['profile_image'],
      postCount: json['post_count'] ?? 0,
      followerCount: json['follower_count'] ?? 0,
      followedCount: json['followed_count'] ?? 0,
      totalLikes: json['total_likes'] ?? 0,
      isFollowing: json['is_following'] ?? false,
    );
  }

  /// ProfileオブジェクトをJSONに変換
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'name': name,
      'bio': bio,
      'profile_image': profileImage,
      'post_count': postCount,
      'follower_count': followerCount,
      'followed_count': followedCount,
      'total_likes': totalLikes,
      'is_following': isFollowing,
    };
  }

  /// プロフィール情報を更新したコピーを作成
  Profile copyWith({
    String? id,
    String? username,
    String? name,
    String? bio,
    String? profileImage,
    int? postCount,
    int? followerCount,
    int? followedCount,
    int? totalLikes,
    bool? isFollowing,
  }) {
    return Profile(
      id: id ?? this.id,
      username: username ?? this.username,
      name: name ?? this.name,
      bio: bio ?? this.bio,
      profileImage: profileImage ?? this.profileImage,
      postCount: postCount ?? this.postCount,
      followerCount: followerCount ?? this.followerCount,
      followedCount: followedCount ?? this.followedCount,
      totalLikes: totalLikes ?? this.totalLikes,
      isFollowing: isFollowing ?? this.isFollowing,
    );
  }

  /// プロフィール情報のバリデーション
  static String? validateUsername(String? value) {
    if (value == null || value.isEmpty) {
      return 'ユーザー名を入力してください';
    }
    if (!RegExp(r'^[a-z0-9_.]+$').hasMatch(value)) {
      return 'ユーザー名は半角英数字、アンダースコア(_)、ドット(.)のみ使用できます';
    }
    return null;
  }

  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return '名前を入力してください';
    }
    if (value.length > 30) {
      return '名前は30文字以内で入力してください';
    }
    return null;
  }

  static String? validateBio(String? value) {
    if (value != null && value.length > 160) {
      return '自己紹介は160文字以内で入力してください';
    }
    return null;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Profile && other.id == id && other.username == username;
  }

  @override
  int get hashCode => Object.hash(id, username);

  @override
  String toString() =>
      'Profile(id: $id, username: $username, name: $name, postCount: $postCount)';
}

/// TerraPicアプリの投稿モデル
///
/// 投稿データの構造を定義し、JSONとの相互変換や
/// バリデーション機能を提供する。
///
/// 主な機能:
/// - 投稿データの構造化
/// - JSONシリアライズ/デシリアライズ
/// - データバリデーション
/// - 便利なゲッターメソッド
///
class Post {
  final int id;
  final String imageUrl;
  final String? description;
  final DateTime createdAt;
  final int likeCount;
  final bool isLiked;
  final PostUser user;
  final PostPlace place;
  final Map<String, dynamic>? photoSpotLocation;
  final String? weather;
  final String? season;

  Post({
    required this.id,
    required this.imageUrl,
    this.description,
    required this.createdAt,
    required this.likeCount,
    required this.isLiked,
    required this.user,
    required this.place,
    this.photoSpotLocation,
    this.weather,
    this.season,
  });

  /// JSONからPostオブジェクトを生成
  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'],
      imageUrl: json['photo_image'],
      description: json['description'],
      createdAt: DateTime.parse(json['created_at']),
      likeCount: json['like_count'] ?? 0,
      isLiked: json['is_liked'] ?? false,
      user: PostUser.fromJson(json['user']),
      place: PostPlace.fromJson(json['place']),
      photoSpotLocation: json['photo_spot_location'],
      weather: json['weather'],
      season: json['season'],
    );
  }

  /// PostオブジェクトをJSONに変換
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'photo_image': imageUrl,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'like_count': likeCount,
      'is_liked': isLiked,
      'user': user.toJson(),
      'place': place.toJson(),
      'photo_spot_location': photoSpotLocation,
      'weather': weather,
      'season': season,
    };
  }

  /// 写真スポットの位置情報を持っているかどうか
  bool get hasPhotoSpot => photoSpotLocation != null;

  /// 写真スポットの緯度を取得
  double? get photoSpotLatitude {
    if (!hasPhotoSpot) return null;
    final coordinates = photoSpotLocation!['coordinates'] as List?;
    return coordinates?[1]?.toDouble();
  }

  /// 写真スポットの経度を取得
  double? get photoSpotLongitude {
    if (!hasPhotoSpot) return null;
    final coordinates = photoSpotLocation!['coordinates'] as List?;
    return coordinates?[0]?.toDouble();
  }

  /// コピーを作成して特定のフィールドを更新
  Post copyWith({
    int? id,
    String? imageUrl,
    String? description,
    DateTime? createdAt,
    int? likeCount,
    bool? isLiked,
    PostUser? user,
    PostPlace? place,
    Map<String, dynamic>? photoSpotLocation,
    String? weather,
    String? season,
  }) {
    return Post(
      id: id ?? this.id,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
      user: user ?? this.user,
      place: place ?? this.place,
      photoSpotLocation: photoSpotLocation ?? this.photoSpotLocation,
      weather: weather ?? this.weather,
      season: season ?? this.season,
    );
  }
}

/// 投稿に関連するユーザー情報
class PostUser {
  final int id;
  final String username;
  final String? profileImage;
  final String? name;

  PostUser({
    required this.id,
    required this.username,
    this.profileImage,
    this.name,
  });

  factory PostUser.fromJson(Map<String, dynamic> json) {
    return PostUser(
      id: json['id'],
      username: json['username'],
      profileImage: json['profile_image'],
      name: json['name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'profile_image': profileImage,
      'name': name,
    };
  }
}

/// 投稿に関連する場所情報
class PostPlace {
  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final double? rating;
  final int postCount;

  PostPlace({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.rating,
    required this.postCount,
  });

  factory PostPlace.fromJson(Map<String, dynamic> json) {
    return PostPlace(
      id: json['id'],
      name: json['name'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      rating: json['rating']?.toDouble(),
      postCount: json['post_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'rating': rating,
      'post_count': postCount,
    };
  }
}

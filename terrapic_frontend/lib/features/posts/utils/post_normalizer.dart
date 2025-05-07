/// TerraPicアプリの投稿データ正規化ユーティリティ
///
/// 異なるAPIエンドポイントから返される投稿データを
/// 統一された形式に変換する機能を提供する。
///
/// 主な機能:
/// - 投稿データの正規化
/// - 画像URLの完全なURLへの変換
/// - 場所情報の統一
///
class PostNormalizer {
  /// 投稿データを正規化する
  ///
  /// [post] 正規化する投稿データ
  /// [baseUrl] APIのベースURL
  static Map<String, dynamic> normalize(
    Map<String, dynamic> post,
    String baseUrl, {
    int? originalIndex,
  }) {
    // IDを整数型に確実に変換
    final int postId =
        post['id'] is int ? post['id'] : int.parse(post['id'].toString());

    // 画像URLの正規化
    String? imageUrl = post['photo_image'] ?? post['url'] ?? post['image_url'];
    if (imageUrl != null && !imageUrl.startsWith('http')) {
      imageUrl = '$baseUrl${imageUrl.startsWith("/") ? "" : "/"}$imageUrl';
    }

    // 場所情報の正規化
    final Map<String, dynamic> placeData = post['place'] ?? {};
    final String placeName = placeData['name'] ??
        post['place_name'] ??
        post['displayed_place_name'] ??
        'Unknown Location';
    final Map<String, dynamic> normalizedPlace = {
      'id': placeData['id'] ?? post['place_id'],
      'name': placeName,
    };

    // ユーザー情報の正規化
    final Map<String, dynamic> userData = post['user'] ?? {};
    String? profileImage = userData['profile_image'];
    if (profileImage != null && !profileImage.startsWith('http')) {
      profileImage =
          '$baseUrl${profileImage.startsWith("/") ? "" : "/"}$profileImage';
    }

    // 正規化されたデータを返す
    return {
      'id': postId,
      'image_url': imageUrl,
      'description': post['description'] ?? '',
      'like_count': post['like_count'] ?? post['likes'] ?? 0,
      'is_liked': post['is_liked'] ?? false,
      'created_at': post['created_at'],
      'original_index': originalIndex, // 元のインデックスを保持
      'user': {
        'id': userData['id']?.toString(),
        'username': userData['username'] ?? 'Unknown User',
        'profile_image': profileImage,
      },
      'place': normalizedPlace,
      'photo_spot_location': post['photo_spot_location'],
      '_source_data': post, // 元のデータを保持（デバッグ用）
    };
  }

  /// 投稿リストを正規化する
  static List<Map<String, dynamic>> normalizeList(
    List<dynamic> posts,
    String baseUrl,
  ) {
    return posts
        .asMap()
        .entries
        .map((entry) => normalize(
              Map<String, dynamic>.from(entry.value),
              baseUrl,
              originalIndex: entry.key,
            ))
        .toList();
  }
}

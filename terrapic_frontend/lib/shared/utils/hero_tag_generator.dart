/// TerraPicアプリのHeroタグ生成ユーティリティ
///
/// 画面間のHeroアニメーションで使用する一意のタグを生成する。
/// 一貫性のあるタグ形式を提供することで、アニメーションの動作を保証する。
///
class HeroTagGenerator {
  /// 投稿画像用のHeroタグを生成する
  ///
  /// [source] タグのソース（例: 'profile', 'place', 'search'）
  /// [postId] 投稿のID
  /// [index] 表示位置のインデックス（オプション）
  /// [userId] ユーザーID（オプション）
  static String generatePostTag({
    required String source,
    required int postId,
    int? index,
    String? userId,
  }) {
    final List<String> components = [
      source, // ソース（必須）
      userId ?? 'global', // ユーザーID（オプション）
      postId.toString(), // 投稿ID（必須）
      if (index != null) index.toString(), // インデックス（オプション）
    ];

    return components.join('_');
  }

  /// タグの構成要素を分解する（デバッグ用）
  static Map<String, String> parseTag(String tag) {
    final parts = tag.split('_');
    return {
      'source': parts[0],
      'userId': parts[1],
      'postId': parts[2],
      if (parts.length > 3) 'index': parts[3],
    };
  }
}

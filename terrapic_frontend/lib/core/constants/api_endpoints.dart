/// TerraPicアプリのAPIエンドポイント定数
///
/// アプリで使用する全てのAPIエンドポイントを一元管理する。
/// エンドポイントの変更や管理を容易にする。
class ApiEndpoints {
  // 認証関連
  static const String login = '/api/token/';
  static const String signup = '/api/signup/';
  static const String refreshToken = '/api/token/refresh/';

  // プロフィール関連
  static const String profile = '/api/profile/';
  static const String profileEdit = '/api/profile/edit/';
  static const String profileLikes = '/api/profile/likes/';
  static const String profileFavorites = '/api/profile/favorites/';

  // 投稿関連
  static const String createPost = '/api/post/create/';
  static const String postLike = '/api/post/{id}/like/';
  static const String postLikeStatus = '/api/post/{id}/like/status/';

  // 場所関連
  static const String places = '/api/places/';
  static const String placeDetail = '/api/places/{id}/details/';
  static const String placeTopPhoto = '/api/places/{id}/top_photo/';
  static const String placeFavorite = '/api/places/{id}/favorite/';
  static const String placeFavoriteStatus = '/api/places/{id}/favorite/status/';
  static const String placeSearch = '/api/post_place_search/';

  // 検索関連
  static const String search = '/api/search/';

  // ユーザー関連
  static const String userProfile = '/api/users/{id}/';
  static const String userFollow = '/api/users/{id}/follow';
  static const String userFollowers = '/api/users/{id}/followers/';
  static const String userFollowing = '/api/users/{id}/following/';

  // ランキング関連
  static const String rankingPlaces = '/api/ranking/places';
  static const String rankingPosts = '/api/ranking/posts';

  /// IDを含むエンドポイントを生成
  static String withId(String endpoint, String id) {
    return endpoint.replaceAll('{id}', id);
  }
}

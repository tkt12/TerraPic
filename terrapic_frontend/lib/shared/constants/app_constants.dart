/// TerraPicアプリの共通定数
///
/// アプリ全体で使用される定数値を管理する。
/// UI設定、制限値、デフォルト値などを定義する。
///
/// 主な定数:
/// - UI関連の設定値
/// - 入力制限値
/// - デフォルト値
/// - エラーメッセージ
///
class AppConstants {
  // UI設定
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double borderRadius = 8.0;
  static const Duration animationDuration = Duration(milliseconds: 300);

  // 入力制限
  static const int maxUsernameLength = 30;
  static const int maxNameLength = 50;
  static const int maxBioLength = 160;
  static const int maxDescriptionLength = 1000;
  static const int minPasswordLength = 8;

  // 画像関連
  static const double maxImageSize = 5 * 1024 * 1024; // 5MB
  static const int imageQuality = 85;
  static const double aspectRatio = 1.0;

  // API関連
  static const int apiTimeout = 30; // 秒
  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 1);

  // キャッシュ関連
  static const Duration cacheExpiration = Duration(days: 7);
  static const int maxCacheSize = 100 * 1024 * 1024; // 100MB

  // ページネーション
  static const int itemsPerPage = 20;
  static const int preloadThreshold = 3;

  // デフォルト値
  static const double defaultRating = 3.0;
  static const int defaultRadius = 5000; // メートル
  static const double defaultZoomLevel = 15.0;

  // エラーメッセージ
  static const String networkError = 'ネットワークエラーが発生しました';
  static const String timeoutError = '接続がタイムアウトしました';
  static const String serverError = 'サーバーエラーが発生しました';
  static const String authError = '認証エラーが発生しました';

  // アプリ情報
  static const String appName = 'TerraPic';
  static const String appVersion = '1.0.0';
  static const String supportEmail = 'support@terrapic.example.com';
}

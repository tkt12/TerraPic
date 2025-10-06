/// TerraPicアプリの設定ファイル
///
/// アプリケーション全体で使用される設定値を管理する
class AppConfig {
  // バックエンドサーバーのURL
  // デフォルトではローカル開発環境のURLを使用
  static const String backendUrl = String.fromEnvironment('BACKEND_URL',
      defaultValue: 'http://localhost:8000');
  // defaultValue: 'http://192.168.100.13:8000');

  // APIエンドポイント
  static const String loginEndpoint = '/api/token/';
  static const String signupEndpoint = '/api/signup/';
  static const String refreshTokenEndpoint = '/api/token/refresh/';
  static const String profileEndpoint = '/api/profile/';

  // トークン設定
  static const int tokenRefreshThresholdMinutes = 15;
  static const Duration tokenExpiration = Duration(hours: 1);
}

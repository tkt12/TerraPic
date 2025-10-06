/// TerraPicアプリの認証状態管理プロバイダー
///
/// アプリケーション全体での認証状態を管理し、適切なタイミングで状態の更新と通知を行う。
/// ビルドサイクル中の状態更新を防ぎ、安定した認証管理を提供する。
///
/// 主な機能:
/// - アプリケーションの認証状態の初期化と管理
/// - ログイン/ログアウト処理の実行
/// - トークンの自動更新
/// - 認証状態の監視と適切なタイミングでの通知
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  // 認証サービスのインスタンス
  final AuthService _authService = AuthService();

  // 認証状態を管理する変数
  bool _isAuthenticated = false;
  String? _userId;
  bool _isLoading = false;
  bool _isInitialized = false;

  // 状態を公開するゲッター
  bool get isAuthenticated => _isAuthenticated;
  String? get userId => _userId;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;

  /// アプリケーションの認証状態を初期化する
  ///
  /// アプリ起動時に必要な認証関連の初期化処理を行う。
  /// - 保存されているトークンの検証
  /// - 必要に応じたトークンの更新
  /// - 初期認証状態の設定
  ///
  /// この処理は一度だけ実行され、完了後に状態の変更を通知する。
  Future<void> initialize() async {
    // 二重初期化の防止
    if (_isInitialized) return;

    _isLoading = true;
    // 初期化中は通知を行わない（ビルドサイクルの問題を防ぐ）

    try {
      // トークンの存在確認
      final token = await _authService.getAccessToken();
      _isAuthenticated = token != null;

      if (_isAuthenticated) {
        // ユーザー情報の復元とトークンの更新確認
        _userId = await _authService.getCurrentUserId();
        final needsRefresh = await _authService.refreshTokenIfNeeded();

        // トークンの更新に失敗した場合は未認証状態に
        if (!needsRefresh) {
          _isAuthenticated = false;
          _userId = null;
        }
      }
    } catch (e) {
      // エラーが発生した場合は未認証状態に
      _isAuthenticated = false;
      _userId = null;
      if (kDebugMode) {
        debugPrint('認証の初期化に失敗しました: $e');
      }
    } finally {
      // 初期化完了後の状態設定
      _isLoading = false;
      _isInitialized = true;
      // 初期化完了時に一度だけ通知
      notifyListeners();
    }
  }

  /// ユーザーログイン処理を実行する
  ///
  /// [email] ログインに使用するメールアドレス
  /// [password] ログインに使用するパスワード
  ///
  /// 戻り値: ログイン結果を含むMap
  /// - success: ログイン成功したかどうか
  /// - message: 結果メッセージ
  Future<Map<String, dynamic>> login(String email, String password) async {
    // ログイン処理開始を通知
    _isLoading = true;
    notifyListeners();

    if (kDebugMode) {
      debugPrint('Start login process');
      debugPrint('Request payload: email=$email');
    }

    try {
      if (kDebugMode) {
        debugPrint('AuthProvider: Starting login process');
      }
      final result = await _authService.login(email, password);
      if (kDebugMode) {
        debugPrint('AuthProvider: Login result received: $result');
      }
      if (result['success']) {
        // ログイン成功時の状態更新
        _userId = await _authService.getCurrentUserId();
        _isAuthenticated = true;
        notifyListeners();
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AuthProvider: Login error: $e');
      }
      // エラー発生時は未認証状態に
      _isAuthenticated = false;
      _userId = null;
      return {'success': false, 'message': 'ログイン処理中にエラーが発生しました: $e'};
    } finally {
      // 処理完了を通知
      _isLoading = false;
      notifyListeners();
    }
  }

  /// ユーザーログアウト処理を実行する
  ///
  /// 保存されているトークンを削除し、認証状態をリセットする
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 保存されている認証情報を削除
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // 認証状態をリセット
      _isAuthenticated = false;
      _userId = null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ログアウト処理中にエラーが発生しました: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// トークンの更新を試行する
  ///
  /// 必要に応じてトークンの更新を行い、更新結果に応じて認証状態を更新する
  ///
  /// 戻り値: 更新が成功したかどうか
  Future<bool> refreshToken() async {
    final success = await _authService.refreshTokenIfNeeded();

    // 更新に失敗した場合は未認証状態に
    if (!success) {
      _isAuthenticated = false;
      _userId = null;
      notifyListeners();
    }

    return success;
  }
}

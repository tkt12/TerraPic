/// TerraPicアプリの認証サービス
///
/// ユーザーの認証に関する処理を管理するサービスクラス。
/// トークンの管理、ログイン、サインアップなどの認証関連の機能を提供する。
///
/// 主な機能:
/// - JWTトークンの管理（保存、取得、リフレッシュ）
/// - ログイン処理
/// - ユーザーIDの取得
/// - トークンの有効期限管理
///
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../core/config/app_config.dart';
import 'dart:async';

class AuthService {
  // トークンの保存キー
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _tokenExpiryKey = 'token_expiry';

  DateTime? _tokenExpiry;

  /// ユーザーIDを取得する
  ///
  /// 現在のアクセストークンからユーザーIDを抽出する
  /// 失敗した場合はnullを返す
  Future<String?> getCurrentUserId() async {
    try {
      final token = await getAccessToken();
      if (token == null) return null;

      final parts = token.split('.');
      if (parts.length != 3) return null;

      final payload = json
          .decode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));

      return payload['user_id']?.toString();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting current user ID: $e');
      }
      return null;
    }
  }

  /// ログイン処理を実行する
  ///
  /// [email] メールアドレス
  /// [password] パスワード
  ///
  /// 成功時は {'success': true, 'message': 'メッセージ'} を返す
  /// 失敗時は {'success': false, 'message': 'エラーメッセージ'} を返す
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      if (kDebugMode) {
        debugPrint('Preparing login request...');
      }
      final url =
          Uri.parse('${AppConfig.backendUrl}${AppConfig.loginEndpoint}');
      if (kDebugMode) {
        debugPrint('Request URL: $url');
      }

      final requestBody = jsonEncode({
        'email': email,
        'password': password,
      });
      if (kDebugMode) {
        debugPrint('Request body: $requestBody');
      }

      final response = await http
          .post(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: requestBody,
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          if (kDebugMode) {
            debugPrint('Request timeout');
          }
          throw TimeoutException('Request timeout');
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        await _saveTokens(responseData['access'], responseData['refresh']);
        _tokenExpiry = DateTime.now().add(AppConfig.tokenExpiration);
        await _saveTokenExpiry(_tokenExpiry!);
        return {'success': true, 'message': 'ログインに成功しました！'};
      } else {
        return {'success': false, 'message': _parseErrorResponse(response)};
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('Login error: $e');
        debugPrint('Stack trace: $stackTrace');
      }
      return {'success': false, 'message': 'エラーが発生しました: ${e.toString()}'};
    }
  }

  /// トークンを保存する
  Future<void> _saveTokens(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);
  }

  /// トークンの有効期限を保存する
  Future<void> _saveTokenExpiry(DateTime expiry) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenExpiryKey, expiry.toIso8601String());
  }

  /// アクセストークンを取得する
  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  /// リフレッシュトークンを取得する
  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  /// トークンの有効期限を確認する
  Future<bool> _shouldRefreshToken() async {
    final expiry = await _getTokenExpiry();
    if (expiry == null) return false;

    final now = DateTime.now();
    final difference = expiry.difference(now).inMinutes;

    return difference <= AppConfig.tokenRefreshThresholdMinutes;
  }

  /// トークンの有効期限を取得する
  Future<DateTime?> _getTokenExpiry() async {
    final prefs = await SharedPreferences.getInstance();
    final expiryStr = prefs.getString(_tokenExpiryKey);
    return expiryStr != null ? DateTime.parse(expiryStr) : null;
  }

  /// トークンを必要に応じてリフレッシュする
  Future<bool> refreshTokenIfNeeded() async {
    try {
      if (await _shouldRefreshToken()) {
        final refreshToken = await getRefreshToken();
        if (refreshToken == null) return false;

        final response = await http.post(
          Uri.parse('${AppConfig.backendUrl}${AppConfig.refreshTokenEndpoint}'),
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode({'refresh': refreshToken}),
        );

        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          await _saveTokens(responseData['access'], refreshToken);
          _tokenExpiry = DateTime.now().add(AppConfig.tokenExpiration);
          await _saveTokenExpiry(_tokenExpiry!);
          return true;
        }
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Token refresh failed: $e');
      }
      return false;
    }
  }

  /// エラーレスポンスをパースする
  String _parseErrorResponse(http.Response response) {
    try {
      final responseData = jsonDecode(response.body);
      if (responseData is Map<String, dynamic> &&
          responseData.containsKey('detail')) {
        return responseData['detail'];
      }
      return '不明なエラーが発生しました';
    } catch (e) {
      return 'エラーが発生しました: ${response.statusCode}';
    }
  }

  /// 認証済みのリクエストを送信する
  Future<http.Response> authenticatedRequest(
    String path, {
    String method = 'GET',
    Map<String, String>? headers,
    dynamic body,
  }) async {
    // トークンを取得
    final token = await getAccessToken();
    if (token == null) {
      throw Exception('認証トークンがありません');
    }

    if (kDebugMode) {
      debugPrint('Using token: $token');
    }

    // ヘッダーの設定
    final defaultHeaders = {
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token', // 'Token ' から 'Bearer ' に変更
    };

    final mergedHeaders = {...defaultHeaders, ...?headers};

    if (kDebugMode) {
      debugPrint('Request headers: $mergedHeaders');
      debugPrint('Request path: ${AppConfig.backendUrl}$path');
    }

    // リクエストの実行
    http.Response response;
    final url = Uri.parse('${AppConfig.backendUrl}$path');

    try {
      switch (method) {
        case 'POST':
          response = await http.post(url, headers: mergedHeaders, body: body);
          break;
        case 'PUT':
          response = await http.put(url, headers: mergedHeaders, body: body);
          break;
        case 'PATCH':
          response = await http.patch(url, headers: mergedHeaders, body: body);
          break;
        case 'DELETE':
          response = await http.delete(url, headers: mergedHeaders, body: body);
          break;
        default:
          response = await http.get(url, headers: mergedHeaders);
      }

      if (kDebugMode) {
        debugPrint('Response status: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
      }

      // 401エラーの場合はトークンの更新を試みる
      if (response.statusCode == 401) {
        final refreshed = await refreshTokenIfNeeded();
        if (refreshed) {
          // トークン更新後に再度リクエストを実行
          return authenticatedRequest(path,
              method: method, headers: headers, body: body);
        }
      }

      return response;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Request error: $e');
      }
      rethrow;
    }
  }
}

/// 認証ヘッダーを生成するユーティリティ関数
Future<Map<String, String>> getAuthHeaders() async {
  final authService = AuthService();
  await authService.refreshTokenIfNeeded();
  final token = await authService.getAccessToken();

  return {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json; charset=UTF-8',
  };
}

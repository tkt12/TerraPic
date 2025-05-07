/// TerraPicアプリのエラーハンドリングユーティリティ
///
/// アプリ全体で統一されたエラー処理を提供する。
/// エラーメッセージの表示やログ記録を管理する。
///
/// 主な機能:
/// - エラーメッセージの表示
/// - エラーのログ記録
/// - エラーの種類に応じた処理
///
import 'package:flutter/material.dart';

class ErrorHandler {
  /// エラーメッセージをスナックバーで表示
  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// エラーダイアログを表示
  static Future<void> showErrorDialog(
    BuildContext context,
    String title,
    String message,
  ) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// APIエラーを処理
  static String handleApiError(dynamic error) {
    if (error is Map) {
      if (error.containsKey('detail')) {
        return error['detail'];
      } else if (error.containsKey('message')) {
        return error['message'];
      }
    }
    return '予期せぬエラーが発生しました';
  }

  /// エラーをログに記録
  static void logError(String message, dynamic error, StackTrace? stackTrace) {
    // TODO: エラーログの実装（Firebaseなど）
    print('Error: $message');
    print('Details: $error');
    if (stackTrace != null) {
      print('StackTrace: $stackTrace');
    }
  }

  /// ネットワークエラーを処理
  static String handleNetworkError(dynamic error) {
    // タイムアウト
    if (error.toString().contains('TimeoutException')) {
      return '通信がタイムアウトしました。ネットワーク接続を確認してください。';
    }
    // 接続エラー
    if (error.toString().contains('SocketException')) {
      return 'ネットワークに接続できません。インターネット接続を確認してください。';
    }
    return 'ネットワークエラーが発生しました。';
  }

  /// 認証エラーを処理
  static void handleAuthError(BuildContext context) {
    showErrorDialog(
      context,
      '認証エラー',
      'セッションが切れました。再度ログインしてください。',
    ).then((_) {
      Navigator.of(context).pushReplacementNamed('/login');
    });
  }
}

/// 日付フォーマットを管理するユーティリティクラス
///
/// 日付の表示形式を統一的に管理し、
/// アプリケーション全体で一貫した日付表示を提供する。
///
/// 主な機能:
/// - 相対的な時間表示（〇分前など）
/// - 日付の標準フォーマット
/// - 日本語対応
///
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class DateFormatter {
  static bool _initialized = false;

  /// DateFormatterの初期化
  static Future<void> initialize() async {
    if (!_initialized) {
      await initializeDateFormatting('ja_JP');
      _initialized = true;
    }
  }

  /// 日時を相対表示または標準フォーマットで返す
  ///
  /// [dateTime] フォーマットする日時
  /// 1分以内: "たった今"
  /// 1時間以内: "○分前"
  /// 24時間以内: "○時間前"
  /// それ以外: "yyyy年MM月dd日"
  static String formatDateTime(DateTime dateTime) {
    try {
      if (!_initialized) {
        // 未初期化の場合は初期化を試みる
        initialize();
      }

      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'たった今';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}分前';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}時間前';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}日前';
      } else {
        // 日本語フォーマットで日付を表示
        final formatter = DateFormat('yyyy年MM月dd日', 'ja_JP');
        return formatter.format(dateTime);
      }
    } catch (e) {
      print('Date formatting error: $e');
      // エラー時は基本的なフォーマットを使用
      return dateTime.toString().split('.')[0];
    }
  }

  /// 日付のみを日本語フォーマットで返す
  static String formatDate(DateTime date) {
    try {
      if (!_initialized) {
        initialize();
      }
      return DateFormat('yyyy年MM月dd日', 'ja_JP').format(date);
    } catch (e) {
      print('Date formatting error: $e');
      return date.toString().split(' ')[0];
    }
  }

  /// 時刻のみを日本語フォーマットで返す
  static String formatTime(DateTime time) {
    try {
      if (!_initialized) {
        initialize();
      }
      return DateFormat('HH:mm', 'ja_JP').format(time);
    } catch (e) {
      print('Time formatting error: $e');
      return time.toString().split(' ')[1].substring(0, 5);
    }
  }

  /// 日付と時刻を日本語フォーマットで返す
  static String formatDateAndTime(DateTime dateTime) {
    try {
      if (!_initialized) {
        initialize();
      }
      return DateFormat('yyyy年MM月dd日 HH:mm', 'ja_JP').format(dateTime);
    } catch (e) {
      print('DateTime formatting error: $e');
      return dateTime.toString().split('.')[0];
    }
  }
}

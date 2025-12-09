import 'package:shared_preferences/shared_preferences.dart';

/// 検索履歴を管理するサービスクラス
class SearchHistoryService {
  static const String _historyKey = 'search_history';
  static const int _maxHistoryItems = 10;

  /// 検索履歴を取得
  static Future<List<String>> getHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList(_historyKey) ?? [];
      return history;
    } catch (e) {
      return [];
    }
  }

  /// 検索履歴に追加
  static Future<void> addToHistory(String query) async {
    if (query.trim().isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> history = prefs.getStringList(_historyKey) ?? [];

      // 既存の同じクエリを削除
      history.remove(query);

      // 先頭に追加
      history.insert(0, query);

      // 最大件数を超えた分を削除
      if (history.length > _maxHistoryItems) {
        history = history.sublist(0, _maxHistoryItems);
      }

      await prefs.setStringList(_historyKey, history);
    } catch (e) {
      // エラーが発生しても検索機能は続行
    }
  }

  /// 検索履歴から削除
  static Future<void> removeFromHistory(String query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> history = prefs.getStringList(_historyKey) ?? [];
      history.remove(query);
      await prefs.setStringList(_historyKey, history);
    } catch (e) {
      // エラーが発生しても検索機能は続行
    }
  }

  /// 検索履歴をクリア
  static Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);
    } catch (e) {
      // エラーが発生しても検索機能は続行
    }
  }
}

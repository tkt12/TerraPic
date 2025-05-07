import 'package:flutter/foundation.dart';

class NavigationProvider extends ChangeNotifier {
  int _currentIndex = 0;
  bool _isTransitioning = false;

  int get currentIndex => _currentIndex;

  void setIndex(int index) {
    // 同じインデックスへの遷移や遷移中の場合は処理をスキップ
    if (_currentIndex == index || _isTransitioning) {
      return;
    }

    // 投稿タブ（通常index = 2）からの遷移の場合は特別な処理
    if (_currentIndex == 2) {
      _isTransitioning = true;
      _currentIndex = index;
      notifyListeners();
      // 遷移完了後にフラグをリセット
      Future.delayed(const Duration(milliseconds: 300), () {
        _isTransitioning = false;
      });
    } else {
      _currentIndex = index;
      notifyListeners();
    }
  }

  // 投稿画面を表示する際の専用メソッド
  void showPostScreen() {
    _currentIndex = 2;
    notifyListeners();
  }

  // インデックスをリセットする
  void resetIndex() {
    _currentIndex = 0;
    notifyListeners();
  }
}

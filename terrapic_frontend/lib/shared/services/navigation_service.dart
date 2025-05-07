/// TerraPicアプリのナビゲーションサービス
///
/// アプリ全体での画面遷移を管理し、一貫したナビゲーション制御を提供する。
/// どの階層からでもメイン画面への遷移を可能にする。
///
/// 主な機能:
/// - メイン画面への直接遷移
/// - ナビゲーションスタックの管理
/// - 投稿画面の特殊処理
/// - 画面状態の保持
///
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/navigation_provider.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/search/screens/search_screen.dart';
import '../../features/posts/screens/post_screen.dart';
import '../../features/ranking/screens/ranking_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../routes/no_animation_page_route.dart';

class NavigationService {
  /// グローバルなナビゲーター用のキー
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// メイン画面のリスト
  static final List<Widget> mainScreens = [
    const HomeScreen(),
    const SearchScreen(),
    const PostScreen(),
    const RankingScreen(),
    const ProfileScreen(),
  ];

  /// タブ画面への遷移を管理
  ///
  /// [context] ビルドコンテキスト
  /// [index] 遷移先のタブインデックス
  static void navigateToTab(BuildContext context, int index) {
    final navigationProvider =
        Provider.of<NavigationProvider>(context, listen: false);

    if (index == 2) {
      _handlePostNavigation(context);
      return;
    }

    Widget screen;
    switch (index) {
      case 0:
        screen = const HomeScreen();
        break;
      case 1:
        screen = const SearchScreen();
        break;
      case 3:
        screen = const RankingScreen();
        break;
      case 4:
        screen = const ProfileScreen();
        break;
      default:
        return;
    }

    // アニメーションなしのルートを使用して遷移
    Navigator.of(context).pushAndRemoveUntil(
      NoAnimationPageRoute(builder: (context) => screen),
      (route) => false,
    );

    // NavigationProviderのインデックスを更新
    navigationProvider.setIndex(index);
  }

  /// 投稿画面への特別な遷移処理
  static Future<void> _handlePostNavigation(BuildContext context) async {
    final navigationProvider =
        Provider.of<NavigationProvider>(context, listen: false);

    try {
      navigationProvider.showPostScreen();
      final result = await Navigator.of(context).push(
        // pushNamed を push に変更
        MaterialPageRoute(
          builder: (context) => const PostScreen(),
        ),
      );

      if (context.mounted) {
        if (result == null) {
          // キャンセルされた場合はホーム画面に戻る
          navigateToTab(context, 0);
        }
      }
    } catch (e) {
      if (context.mounted) {
        navigateToTab(context, 0);
      }
    }
  }

  /// 同じタブが選択された場合のハンドリング
  static void handleSameTabTap(BuildContext context, int index) {
    final navigator = Navigator.of(context);
    if (!navigator.canPop()) return;

    navigateToTab(context, index);
  }

  /// ログアウト時の遷移
  static void logout(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/login',
      (route) => false,
    );
  }

  /// 前の画面に戻る
  static void goBack(BuildContext context, [dynamic result]) {
    Navigator.of(context).pop(result);
  }
}

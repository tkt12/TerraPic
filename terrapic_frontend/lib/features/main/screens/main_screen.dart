/// TerraPicアプリのメイン画面
///
/// ボトムナビゲーションを使用して主要な画面間を遷移する。
/// 画面の切り替えとナビゲーション状態の管理を行う。
///
/// 主な機能:
/// - ボトムナビゲーションの管理
/// - 画面切り替えの制御
/// - 認証状態の監視
///
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// 画面遷移とナビゲーション状態の管理用プロバイダー
import '../../../shared/providers/navigation_provider.dart';
// ユーザーの認証状態を管理するプロバイダー
import '../../auth/providers/auth_provider.dart';
// 各画面のインポート
import '../../home/screens/home_screen.dart';
import '../../search/screens/search_screen.dart';
import '../../posts/screens/post_screen.dart';
import '../../ranking/screens/ranking_screen.dart';
import '../../profile/screens/profile_screen.dart';

/// メイン画面のStatefulWidget
class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

/// メイン画面のState
class _MainScreenState extends State<MainScreen> {
  // アプリの主要な画面をリストで管理
  final List<Widget> _screens = [
    const HomeScreen(), // ホーム画面
    const SearchScreen(), // 検索画面
    const PostScreen(), // 投稿画面
    const RankingScreen(), // ランキング画面
    const ProfileScreen(), // プロフィール画面
  ];

  @override
  void initState() {
    super.initState();
    // 画面表示後に認証状態をチェック
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      // 未認証の場合はログイン画面に遷移
      if (!authProvider.isAuthenticated) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 明示的にホームタブを選択
    Provider.of<NavigationProvider>(context, listen: false).setIndex(0);
    // NavigationProviderの状態を監視
    return Consumer<NavigationProvider>(
      builder: (context, navigationProvider, child) {
        return PopScope(
          canPop: false, // 戻るボタンでアプリを終了させない
          child: Scaffold(
            // IndexedStackで画面を切り替え（状態を保持）
            body: IndexedStack(
              index: navigationProvider.currentIndex,
              children: _screens,
            ),
          ),
        );
      },
    );
  }
}

/// アニメーションなしのルート遷移用クラス
///
/// 画面遷移時のアニメーションを無効化し、
/// 即座に画面を切り替えるためのカスタムルート
class NoAnimationMaterialPageRoute<T> extends MaterialPageRoute<T> {
  NoAnimationMaterialPageRoute({
    required WidgetBuilder builder,
    RouteSettings? settings,
  }) : super(builder: builder, settings: settings);

  /// アニメーションの持続時間を0に設定
  @override
  Duration get transitionDuration => const Duration(milliseconds: 0);

  /// 遷移アニメーションをバイパス
  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

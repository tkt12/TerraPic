/// TerraPicアプリの基本レイアウト
///
/// 全画面で使用される共通のレイアウトコンポーネント。
/// ナビゲーションバーやテーマの適用を管理する。
///
/// 主な機能:
/// - 共通テーマの適用
/// - ボトムナビゲーションの表示制御
/// - 画面遷移の管理
///
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/navigation_provider.dart';
import './custom_bottom_navigation_bar.dart';

class BaseLayout extends StatelessWidget {
  final Widget child;
  final bool showBottomBar;
  final PreferredSizeWidget? appBar;

  const BaseLayout({
    Key? key,
    required this.child,
    this.showBottomBar = true,
    this.appBar,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<NavigationProvider>(
      builder: (context, navigationProvider, _) {
        return Theme(
          data: Theme.of(context).copyWith(
            scaffoldBackgroundColor: Colors.white,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              iconTheme: IconThemeData(color: Colors.black),
              titleTextStyle: TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            bottomNavigationBarTheme: const BottomNavigationBarThemeData(
              backgroundColor: Colors.white,
              elevation: 0,
              selectedItemColor: Colors.blue,
              unselectedItemColor: Colors.grey,
            ),
            colorScheme: const ColorScheme.light(
              surface: Colors.white,
              primary: Colors.blue,
            ),
          ),
          child: Container(
            color: Colors.white,
            child: Scaffold(
              backgroundColor: Colors.white,
              appBar: appBar,
              body: child,
              bottomNavigationBar: showBottomBar
                  ? CustomBottomNavigationBar(
                      currentIndex: navigationProvider.currentIndex,
                      onTap: (index) {
                        navigationProvider.setIndex(index);
                      },
                    )
                  : null,
            ),
          ),
        );
      },
    );
  }
}

/// TerraPicアプリのメインエントリーポイント
///
/// アプリケーションの初期化、設定、ルーティング、
/// プロバイダーの設定などを行う。
///
/// 主な機能:
/// - アプリケーションの初期化
/// - 権限の要求と設定
/// - プロバイダーの設定
/// - ルーティングの設定
/// - テーマの設定
///
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/signup_screen.dart';
import 'features/main/screens/main_screen.dart';
import 'features/auth/providers/auth_provider.dart';
import 'shared/providers/navigation_provider.dart';
import 'shared/services/navigation_service.dart';

/// アプリケーションのエントリーポイント
///
/// 必要な初期化を行い、アプリケーションを起動する
void main() async {
  // Flutterバインディングの初期化
  // プラットフォームチャネルを使用する前に必要
  WidgetsFlutterBinding.ensureInitialized();

  // 日本語ロケールの初期化
  await initializeDateFormatting('ja_JP', null);
  Intl.defaultLocale = 'ja_JP';

  // アプリケーションの初期化
  await _initializeApp();

  // アプリケーションの実行
  runApp(
    MultiProvider(
      providers: [
        // 認証状態の管理
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        // ナビゲーション状態の管理
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

/// アプリケーションの初期化処理
///
/// 必要な権限の要求と画面の向きの設定を行う
Future<void> _initializeApp() async {
  try {
    // 必要な権限を同時に要求
    await Future.wait([
      ph.Permission.camera.request(), // カメラ権限
      ph.Permission.location.request(), // 位置情報権限
      ph.Permission.photos.request(), // 写真ライブラリ権限
    ]);

    // アプリの向きを縦画面に固定
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  } catch (e) {
    print('Initialization error: $e');
  }
}

/// メインアプリケーションウィジェット
///
/// アプリケーションの全体的な設定とルーティングを定義する
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // グローバルなナビゲーションキーを設定
      navigatorKey: NavigationService.navigatorKey,

      // アプリケーションのタイトル
      title: 'TerraPic',

      // アプリケーションのテーマ設定
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        // AppBarのテーマ設定
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
      ),

      // ロケール設定
      locale: const Locale('ja', 'JP'),

      // 初期ルート
      initialRoute: '/',

      // ルート定義
      routes: {
        '/': (context) => const AuthWrapper(), // 認証ラッパー
        '/login': (context) => const LoginScreen(), // ログイン画面
        '/signup': (context) => const SignupScreen(), // サインアップ画面
        '/main': (context) => const MainScreen(), // メイン画面
      },
    );
  }
}

/// 認証状態に基づいて適切な画面を表示するラッパー
///
/// 認証状態を監視し、適切な画面（ログインまたはメイン画面）を表示する
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // ローディング状態の表示
        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 認証状態に基づいて画面を表示
        if (authProvider.isAuthenticated) {
          return const MainScreen();
        }

        return const LoginScreen();
      },
    );
  }
}

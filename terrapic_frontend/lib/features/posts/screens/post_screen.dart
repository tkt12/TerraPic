/// TerraPicアプリの投稿画面
///
/// 写真の選択から投稿完了までの一連の流れを管理する。
/// 写真選択、場所選択、詳細情報の入力を順番に行う。
///
/// 主な機能:
/// - 写真のギャラリー選択
/// - 場所の選択と写真スポットの指定
/// - 投稿詳細（説明、評価など）の入力
/// - 投稿データのアップロード
///
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../shared/providers/navigation_provider.dart';
import '../../../shared/widgets/base_layout.dart';
import '../../../shared/services/navigation_service.dart';
import 'post_form_screen.dart';

/// 投稿画面のStatefulWidget
///
/// 画像選択から投稿までの一連のフローを管理する
class PostScreen extends StatefulWidget {
  const PostScreen({Key? key}) : super(key: key);

  @override
  _PostScreenState createState() => _PostScreenState();
}

/// 投稿画面のState
///
/// 画像選択の状態管理と画面遷移を制御する
class _PostScreenState extends State<PostScreen> {
  // イメージピッカーのインスタンス
  final ImagePicker _picker = ImagePicker();

  // 画像選択中かどうかのフラグ
  bool _isPickingImage = false;

  // 画像選択の初期化が完了したかどうかのフラグ
  bool _didInitiateImagePick = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final navigationProvider =
        Provider.of<NavigationProvider>(context, listen: false);

    // 初回のみ画像選択を開始
    if (!_didInitiateImagePick && navigationProvider.currentIndex == 2) {
      _didInitiateImagePick = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isPickingImage) {
          _isPickingImage = true;
          _pickImage();
        }
      });
    }
  }

  /// 画像を選択する
  ///
  /// ギャラリーから画像を選択し、選択結果に応じて適切な画面に遷移する
  /// - 画像が選択された場合: 投稿詳細入力画面に遷移
  /// - 画像が選択されなかった場合: ホーム画面に戻る
  ///
  Future<void> _pickImage() async {
    try {
      if (kDebugMode) {
        debugPrint("画像選択を開始します");
      }
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (!mounted) return;

      if (pickedFile != null) {
        if (kDebugMode) {
          debugPrint("画像が選択されました: ${pickedFile.path}");
        }
        // 画像が選択された場合、詳細入力画面に遷移
        await Navigator.push(
          // pushReplacement から push に変更
          context,
          MaterialPageRoute(
            builder: (context) => PostFormScreen(image: File(pickedFile.path)),
          ),
        );
      } else {
        if (kDebugMode) {
          debugPrint("画像選択がキャンセルされました");
        }
        // 画像が選択されなかった場合、ホーム画面に戻る
        Navigator.of(context).pop(); // まずモーダルを閉じる
        if (mounted) _returnToHome(); // その後ホームに戻る
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("エラーが発生しました: $e");
      }
      if (!mounted) return;
      _showError('画像の選択中にエラーが発生しました');
      Navigator.of(context).pop(); // まずモーダルを閉じる
      if (mounted) _returnToHome();
    } finally {
      if (mounted) {
        setState(() => _isPickingImage = false);
      }
    }
  }

  /// エラーメッセージを表示する
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// ホーム画面に戻る
  ///
  /// ナビゲーションプロバイダーを使用してホームタブに切り替える
  void _returnToHome() {
    final navigationProvider = Provider.of<NavigationProvider>(
      context,
      listen: false,
    );
    navigationProvider.setIndex(0); // ホームタブに切り替え

    // NavigationServiceを使用して画面状態も更新
    NavigationService.navigateToTab(context, 0);
  }

  @override
  Widget build(BuildContext context) {
    // ローディング画面を表示
    return BaseLayout(
      child: Scaffold(
        body: Container(
          color: Colors.black.withOpacity(0.5),
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

/// アニメーションなしのルート遷移用クラス
///
/// 画面遷移時のアニメーションを無効化するためのカスタムルート
class NoAnimationMaterialPageRoute<T> extends MaterialPageRoute<T> {
  NoAnimationMaterialPageRoute({
    required WidgetBuilder builder,
    RouteSettings? settings,
  }) : super(builder: builder, settings: settings);

  @override
  Duration get transitionDuration => const Duration(milliseconds: 0);

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

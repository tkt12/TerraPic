/// TerraPicアプリの地図上のサークルメニュー
///
/// 地図画面で使用される円形のクイックアクションメニュー。
/// 現在地への移動やフィルター操作などの機能を提供する。
///
/// 主な機能:
/// - 現在地への移動
/// - 表示フィルターの切り替え
/// - ズームコントロール
///
import 'package:flutter/material.dart';

class MapCircleMenu extends StatelessWidget {
  final VoidCallback onLocationPressed;

  const MapCircleMenu({
    Key? key,
    required this.onLocationPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 100,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Tooltip(
          message: '現在地に移動',
          child: MaterialButton(
            onPressed: onLocationPressed,
            color: Colors.white,
            textColor: Colors.black87,
            padding: EdgeInsets.zero,
            shape: const CircleBorder(),
            height: 40,
            minWidth: 40,
            child: const Icon(Icons.my_location),
          ),
        ),
      ),
    );
  }
}

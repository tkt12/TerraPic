/// TerraPicアプリの画像処理ユーティリティ
///
/// 画像の読み込み、キャッシュ、URL生成などの
/// 画像関連の機能を提供する。
///
/// 主な機能:
/// - 画像のプリロード
/// - 画像URLの生成
/// - 画像のキャッシュ管理
/// - 画像の圧縮と最適化
///
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../../core/config/app_config.dart';
import 'dart:io';

class ImageHelper {
  static final DefaultCacheManager _cacheManager = DefaultCacheManager();

  /// 画像をプリロード
  static Future<void> preloadImage(String imageUrl) async {
    try {
      await _cacheManager.downloadFile(imageUrl);
    } catch (e) {
      print('Error preloading image: $e');
    }
  }

  /// 完全なイメージURLを取得
  static String getFullImageUrl(String? partialUrl) {
    if (partialUrl == null || partialUrl.isEmpty) {
      return '';
    }

    if (partialUrl.startsWith('http://') || partialUrl.startsWith('https://')) {
      return partialUrl;
    }

    return '${AppConfig.backendUrl}$partialUrl';
  }

  /// キャッシュから画像を取得
  static Future<File?> getCachedImage(String imageUrl) async {
    try {
      final fileInfo = await _cacheManager.getFileFromCache(imageUrl);
      return fileInfo?.file;
    } catch (e) {
      print('Error getting cached image: $e');
      return null;
    }
  }

  /// 画像をキャッシュに保存
  static Future<void> cacheImage(String imageUrl) async {
    try {
      await _cacheManager.downloadFile(imageUrl);
    } catch (e) {
      print('Error caching image: $e');
    }
  }

  /// キャッシュから画像を削除
  static Future<void> removeFromCache(String imageUrl) async {
    try {
      await _cacheManager.removeFile(imageUrl);
    } catch (e) {
      print('Error removing image from cache: $e');
    }
  }

  /// キャッシュをクリア
  static Future<void> clearCache() async {
    try {
      await _cacheManager.emptyCache();
    } catch (e) {
      print('Error clearing image cache: $e');
    }
  }

  /// 画像のキャッシュ状態を確認
  static Future<bool> isImageCached(String imageUrl) async {
    try {
      final fileInfo = await _cacheManager.getFileFromCache(imageUrl);
      return fileInfo != null;
    } catch (e) {
      print('Error checking image cache status: $e');
      return false;
    }
  }

  /// プレースホルダー画像のURLを生成
  static String getPlaceholderUrl({
    required int width,
    required int height,
  }) {
    return '/api/placeholder/$width/$height';
  }

  /// 画像のアスペクト比を計算
  static double calculateAspectRatio(int width, int height) {
    return width / height;
  }
}

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
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../../core/config/app_config.dart';
import 'dart:io';
import 'package:exif/exif.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ImageHelper {
  static final DefaultCacheManager _cacheManager = DefaultCacheManager();

  /// 画像をプリロード
  static Future<void> preloadImage(String imageUrl) async {
    try {
      await _cacheManager.downloadFile(imageUrl);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error preloading image: $e');
      }
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
      if (kDebugMode) {
        debugPrint('Error getting cached image: $e');
      }
      return null;
    }
  }

  /// 画像をキャッシュに保存
  static Future<void> cacheImage(String imageUrl) async {
    try {
      await _cacheManager.downloadFile(imageUrl);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error caching image: $e');
      }
    }
  }

  /// キャッシュから画像を削除
  static Future<void> removeFromCache(String imageUrl) async {
    try {
      await _cacheManager.removeFile(imageUrl);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error removing image from cache: $e');
      }
    }
  }

  /// キャッシュをクリア
  static Future<void> clearCache() async {
    try {
      await _cacheManager.emptyCache();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error clearing image cache: $e');
      }
    }
  }

  /// 画像のキャッシュ状態を確認
  static Future<bool> isImageCached(String imageUrl) async {
    try {
      final fileInfo = await _cacheManager.getFileFromCache(imageUrl);
      return fileInfo != null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error checking image cache status: $e');
      }
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

  /// 画像のEXIFデータから位置情報を取得
  ///
  /// 戻り値: 位置情報が存在する場合はLatLng、存在しない場合はnull
  static Future<LatLng?> getLocationFromImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final data = await readExifFromBytes(bytes);

      if (data.isEmpty) {
        if (kDebugMode) {
          debugPrint('No EXIF data found in image');
        }
        return null;
      }

      // GPS情報の取得
      final gpsLatitude = data['GPS GPSLatitude'];
      final gpsLatitudeRef = data['GPS GPSLatitudeRef'];
      final gpsLongitude = data['GPS GPSLongitude'];
      final gpsLongitudeRef = data['GPS GPSLongitudeRef'];

      if (gpsLatitude == null ||
          gpsLatitudeRef == null ||
          gpsLongitude == null ||
          gpsLongitudeRef == null) {
        if (kDebugMode) {
          debugPrint('GPS data not found in EXIF');
        }
        return null;
      }

      // 緯度の変換（型キャストを追加）
      final lat = _convertToDecimalDegrees(
        gpsLatitude.values.toList().cast<Ratio>(),
        gpsLatitudeRef.printable,
      );

      // 経度の変換（型キャストを追加）
      final lng = _convertToDecimalDegrees(
        gpsLongitude.values.toList().cast<Ratio>(),
        gpsLongitudeRef.printable,
      );

      if (lat == null || lng == null) {
        if (kDebugMode) {
          debugPrint('Failed to convert GPS coordinates');
        }
        return null;
      }

      if (kDebugMode) {
        debugPrint('Found GPS coordinates: $lat, $lng');
      }
      return LatLng(lat, lng);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error reading EXIF data: $e');
      }
      return null;
    }
  }

  /// GPS座標を度分秒から10進数形式に変換
  static double? _convertToDecimalDegrees(
    List<Ratio> coordinates,
    String ref,
  ) {
    try {
      if (coordinates.length < 3) return null;

      final degrees = coordinates[0].toDouble();
      final minutes = coordinates[1].toDouble();
      final seconds = coordinates[2].toDouble();

      var decimal = degrees + (minutes / 60.0) + (seconds / 3600.0);

      // 南半球または西半球の場合は負の値にする
      if (ref == 'S' || ref == 'W') {
        decimal = -decimal;
      }

      return decimal;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error converting GPS coordinates: $e');
      }
      return null;
    }
  }
}

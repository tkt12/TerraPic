/// TerraPicアプリの場所モデル
///
/// 場所の情報を管理するモデルクラス。
/// 基本的な場所情報と写真スポットの位置情報を保持する。
///
/// 主なデータ:
/// - 場所のID
/// - 場所の名前
/// - 基準位置（緯度・経度）
/// - 写真スポットの位置（緯度・経度）
/// - 住所情報
import 'dart:math';

class Place {
  final String id;
  final String name;
  final String? formattedAddress;
  final double latitude;
  final double longitude;
  final double? photoSpotLatitude;
  final double? photoSpotLongitude;

  Place({
    required this.id,
    required this.name,
    this.formattedAddress,
    required this.latitude,
    required this.longitude,
    this.photoSpotLatitude,
    this.photoSpotLongitude,
  });

  /// JSONからPlaceオブジェクトを生成
  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      id: json['id'].toString(),
      name: json['name'],
      formattedAddress: json['formatted_address'],
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      photoSpotLatitude: json['photo_spot_latitude']?.toDouble(),
      photoSpotLongitude: json['photo_spot_longitude']?.toDouble(),
    );
  }

  /// PlaceオブジェクトをJSONに変換
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'formatted_address': formattedAddress,
      'latitude': latitude,
      'longitude': longitude,
      'photo_spot_latitude': photoSpotLatitude,
      'photo_spot_longitude': photoSpotLongitude,
    };
  }

  /// 写真スポットの位置情報が設定されているかどうかを確認
  bool get hasPhotoSpot =>
      photoSpotLatitude != null && photoSpotLongitude != null;

  /// 写真スポットの位置情報を更新したコピーを生成
  Place copyWithPhotoSpot({
    required double photoSpotLatitude,
    required double photoSpotLongitude,
  }) {
    return Place(
      id: id,
      name: name,
      formattedAddress: formattedAddress,
      latitude: latitude,
      longitude: longitude,
      photoSpotLatitude: photoSpotLatitude,
      photoSpotLongitude: photoSpotLongitude,
    );
  }

  /// 基準位置と写真スポットの距離を計算
  double? getDistanceToPhotoSpot() {
    if (!hasPhotoSpot) return null;

    // ここに距離計算のロジックを実装
    // 例: Haversine公式を使用した距離計算
    return _calculateDistance(
      latitude,
      longitude,
      photoSpotLatitude!,
      photoSpotLongitude!,
    );
  }

  /// 2点間の距離を計算（Haversine公式）
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000; // 地球の半径（メートル）

    // 緯度経度をラジアンに変換
    final double phi1 = _degreesToRadians(lat1);
    final double phi2 = _degreesToRadians(lat2);
    final double deltaPhi = _degreesToRadians(lat2 - lat1);
    final double deltaLambda = _degreesToRadians(lon2 - lon1);

    final double a =
        _haversine(deltaPhi) + cos(phi1) * cos(phi2) * _haversine(deltaLambda);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  /// 度をラジアンに変換
  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  /// Haversine関数
  double _haversine(double rad) {
    return pow(sin(rad / 2), 2).toDouble();
  }

  /// 文字列表現を生成
  @override
  String toString() {
    return 'Place{id: $id, name: $name, latitude: $latitude, longitude: $longitude, '
        'photoSpotLatitude: $photoSpotLatitude, photoSpotLongitude: $photoSpotLongitude}';
  }

  /// 等価性の判定
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Place &&
        other.id == id &&
        other.name == name &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.photoSpotLatitude == photoSpotLatitude &&
        other.photoSpotLongitude == photoSpotLongitude;
  }

  /// ハッシュコード
  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      latitude,
      longitude,
      photoSpotLatitude,
      photoSpotLongitude,
    );
  }
}

/// 場所データのバリデーション用
class PlaceValidation {
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return '場所の名前を入力してください';
    }
    return null;
  }

  static String? validateCoordinates(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) {
      return '位置情報が必要です';
    }
    if (latitude < -90 || latitude > 90) {
      return '緯度が範囲外です';
    }
    if (longitude < -180 || longitude > 180) {
      return '経度が範囲外です';
    }
    return null;
  }
}

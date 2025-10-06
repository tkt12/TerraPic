/// TerraPicアプリのホーム画面
///
/// GoogleMapを使用して場所と投稿を表示する。
/// 現在地の取得、マーカーの表示、場所の詳細表示などの機能を提供する。
///
/// 主な機能:
/// - 地図の表示と操作
/// - 現在地の取得と表示
/// - 投稿場所のマーカー表示
/// - 場所の詳細情報の表示
/// - 写真スポットの表示
///
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

import '../../../core/config/app_config.dart';
import '../../../shared/widgets/custom_info_window.dart';
import '../../../shared/widgets/base_layout.dart';
import '../../places/screens/place_detail_screen.dart';
import '../widgets/map_circle_menu.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // コントローラー
  GoogleMapController? mapController;
  Location location = Location();
  late final AnimationController _animationController;
  late final Animation<double> _animation;

  // 状態変数
  LocationData? _locationData;
  Set<Marker> _visibleMarkers = {};
  bool _isLoading = true;
  bool _serviceEnabled = false;
  PermissionStatus? _permissionGranted;
  Timer? _debounceTimer;

  // 選択された場所の情報
  Map<String, dynamic>? _selectedPlace;
  Map<String, dynamic>? _selectedPhotoData;

  // 定数
  static const LatLng _tokyoLocation = LatLng(35.682839, 139.759455);
  static const int _locationTimeout = 5;
  static const double _detailZoomThreshold = 16.0;

  String? _mapStyle;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();

    // アニメーションコントローラーの初期化
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );

    // フェードアニメーションの設定
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _isInitialized = true;

    // 地図スタイルの読み込みと位置情報の権限チェック
    _loadMapStyle();
    _checkLocationPermission();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    mapController?.dispose();
    if (_isInitialized) {
      _animationController.dispose();
    }
    super.dispose();
  }

  /// マップスタイルを読み込む
  Future<void> _loadMapStyle() async {
    try {
      _mapStyle = await rootBundle.loadString('assets/map_style_nature.json');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('地図スタイルの読み込みに失敗しました: $e');
      }
    }
  }

  /// 位置情報の権限をチェック
  Future<void> _checkLocationPermission() async {
    if (!mounted) return;

    try {
      // 位置情報サービスの有効性を確認
      _serviceEnabled = await location.serviceEnabled();
      if (!_serviceEnabled) {
        _serviceEnabled = await location.requestService();
        if (!_serviceEnabled) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          return;
        }
      }

      // 位置情報の権限を確認
      _permissionGranted = await location.hasPermission();
      if (_permissionGranted == PermissionStatus.denied) {
        _permissionGranted = await location.requestPermission();
        if (_permissionGranted != PermissionStatus.granted) {
          if (!mounted) return;
          _showPermissionDeniedDialog();
          return;
        }
      }

      // 位置情報の初期化
      await _initializeLocation();
    } catch (e) {
      if (!mounted) return;
      _handleLocationError('位置情報の設定中にエラーが発生しました: $e');
    }
  }

  /// 位置情報を初期化
  Future<void> _initializeLocation() async {
    if (!mounted) return;

    try {
      final locationData = await _getLocationWithTimeout();
      if (!mounted) return;

      if (locationData != null) {
        setState(() {
          _locationData = locationData;
          _isLoading = false;
        });
        await _moveToCurrentLocation();
      } else {
        _handleLocationError('位置情報を取得できませんでした');
      }
    } catch (e) {
      if (!mounted) return;
      _handleLocationError('エラー: $e');
    }
  }

  /// タイムアウト付きで位置情報を取得
  Future<LocationData?> _getLocationWithTimeout() async {
    try {
      return await location.getLocation().timeout(
            Duration(seconds: _locationTimeout),
          );
    } on TimeoutException catch (_) {
      throw '位置情報の取得がタイムアウトしました';
    } catch (e) {
      throw '位置情報の取得中にエラーが発生しました: $e';
    }
  }

  /// 現在地に移動
  Future<void> _moveToCurrentLocation() async {
    if (!mounted || mapController == null || _locationData == null) return;

    try {
      await mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(_locationData!.latitude!, _locationData!.longitude!),
            zoom: 15.0,
          ),
        ),
      );
      await _fetchVisibleMarkers();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error moving to current location: $e');
      }
    }
  }

  /// 表示範囲内のマーカーを取得
  Future<void> _fetchVisibleMarkers() async {
    if (!mounted || mapController == null) return;

    try {
      final visibleRegion = await mapController!.getVisibleRegion();
      final zoomLevel = await mapController!.getZoomLevel();

      final response = await http.get(Uri.parse(
          '${AppConfig.backendUrl}/api/places/?min_lat=${visibleRegion.southwest.latitude}'
          '&max_lat=${visibleRegion.northeast.latitude}'
          '&min_lon=${visibleRegion.southwest.longitude}'
          '&max_lon=${visibleRegion.northeast.longitude}'));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> places =
            json.decode(utf8.decode(response.bodyBytes));
        if (kDebugMode) {
          debugPrint("API Response Data:");
          debugPrint(json.encode(places));

          // 各場所のpostsデータも確認
          for (var place in places) {
            debugPrint("Place ID: ${place['id']}");
            debugPrint("Posts data:");
            debugPrint(json.encode(place['posts']));
          }
        }
        _updateMarkers(places, zoomLevel);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching markers: $e');
      }
    }
  }

  /// マーカーを更新
  void _updateMarkers(List<dynamic> places, double zoomLevel) {
    final bool shouldShowPhotoSpots = zoomLevel >= _detailZoomThreshold;

    setState(() {
      _visibleMarkers.clear();
      if (kDebugMode) {
        debugPrint("Updating markers - Zoom Level: $zoomLevel");
        debugPrint("Showing Photo Spots: $shouldShowPhotoSpots");
      }

      for (var place in places) {
        if (place['post_count'] > 0) {
          if (shouldShowPhotoSpots) {
            // ズームレベルが16以上: 各投稿の撮影地点にマーカーを表示
            _addPhotoSpotMarkers(place);
          } else {
            // ズームレベルが16未満: 場所の中心座標にマーカーを表示
            _addPlaceMarker(place);
          }
        }
      }
    });
  }

  /// 写真スポットのマーカーを追加
  void _addPhotoSpotMarkers(Map<String, dynamic> place) {
    final posts = place['posts'] as List<dynamic>;
    if (kDebugMode) {
      debugPrint(
          "Adding Photo Spot Markers for place: ${place['id']} with ${posts.length} posts");
    }

    for (var post in posts) {
      if (post['photo_spot_location'] != null) {
        final photoSpot = post['photo_spot_location'];
        if (kDebugMode) {
          debugPrint(
              "Adding marker for post ${post['id']} at ${photoSpot['latitude']}, ${photoSpot['longitude']}");
        }

        _visibleMarkers.add(
          Marker(
            markerId: MarkerId('post_${post['id']}'),
            position: LatLng(
              photoSpot['latitude'],
              photoSpot['longitude'],
            ),
            icon:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            onTap: () => _onMarkerTapped({
              ...place,
              'latitude': photoSpot['latitude'],
              'longitude': photoSpot['longitude'],
              'is_photo_spot': true,
              'post_id': post['id'],
            }),
          ),
        );
      }
    }
  }

  /// 場所のマーカーを追加
  void _addPlaceMarker(Map<String, dynamic> place) {
    if (kDebugMode) {
      debugPrint(
          "Adding Place Marker for place: ${place['id']} at ${place['latitude']}, ${place['longitude']}");
    }

    _visibleMarkers.add(
      Marker(
        markerId: MarkerId('place_${place['id']}'),
        position: LatLng(place['latitude'], place['longitude']),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        onTap: () => _onMarkerTapped({
          ...place,
          'is_photo_spot': false,
        }),
      ),
    );
  }

  /// マーカータップ時の処理
  Future<void> _onMarkerTapped(Map<String, dynamic> place) async {
    if (!mounted) return;

    try {
      if (_selectedPlace != null) {
        await _animationController.reverse();
      }

      String url =
          '${AppConfig.backendUrl}/api/places/${place['id']}/top_photo/';

      if (place['is_photo_spot'] == true &&
          place['latitude'] != null &&
          place['longitude'] != null) {
        url += '?latitude=${place['latitude']}&longitude=${place['longitude']}';
      }

      final response = await http.get(Uri.parse(url));

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _selectedPlace = place;
          _selectedPhotoData = json.decode(utf8.decode(response.bodyBytes));
        });
        await Future.wait([
          _animateCamera(place),
          _animationController.forward(),
        ]);
      } else {
        _showErrorSnackBar('写真の取得に失敗しました');
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('エラーが発生しました');
    }
  }

  /// カメラの移動
  Future<void> _animateCamera(Map<String, dynamic> place) async {
    if (!mounted || mapController == null) return;

    try {
      final LatLng markerPosition =
          LatLng(place['latitude'], place['longitude']);
      final LatLngBounds visibleRegion =
          await mapController!.getVisibleRegion();
      final double latDifference =
          visibleRegion.northeast.latitude - visibleRegion.southwest.latitude;
      final LatLng newCenter = LatLng(
        markerPosition.latitude + (latDifference * 0.1),
        markerPosition.longitude,
      );

      return mapController!.animateCamera(CameraUpdate.newLatLng(newCenter));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error animating camera: $e');
      }
    }
  }

  /// エラーメッセージを表示
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// 権限拒否時のダイアログを表示
  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('位置情報の権限が必要です'),
        content:
            const Text('このアプリの機能を十分に活用するには、位置情報の権限が必要です。設定画面から権限を許可してください。'),
        actions: <Widget>[
          TextButton(
            child: const Text('設定を開く'),
            onPressed: () {
              ph.openAppSettings();
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: const Text('キャンセル'),
            onPressed: () {
              Navigator.of(context).pop();
              setState(() => _isLoading = false);
            },
          ),
        ],
      ),
    );
  }

  /// 位置情報のエラーを処理
  void _handleLocationError(String message) {
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// 場所の詳細画面に遷移
  void _navigateToPlaceDetail() {
    if (_selectedPlace != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlaceDetailScreen(place: _selectedPlace!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseLayout(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('TerraPic'),
        ),
        body: Stack(
          children: [
            // Google Maps
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _locationData != null
                    ? LatLng(
                        _locationData!.latitude!, _locationData!.longitude!)
                    : _tokyoLocation,
                zoom: 12.0,
              ),
              onMapCreated: (controller) {
                mapController = controller;
              },
              style: _mapStyle,
              myLocationEnabled: _permissionGranted == PermissionStatus.granted,
              myLocationButtonEnabled: false,
              markers: _visibleMarkers,
              onCameraMove: (_) {},
              onCameraIdle: () {
                _debounceTimer?.cancel();
                _debounceTimer = Timer(
                  const Duration(milliseconds: 500),
                  () async {
                    final zoom = await mapController!.getZoomLevel();
                    if (kDebugMode) {
                      debugPrint("Current Zoom Level: $zoom");
                    }
                    _fetchVisibleMarkers();
                  },
                );
              },
              onTap: (_) async {
                if (_selectedPlace != null) {
                  await _animationController.reverse();
                  setState(() {
                    _selectedPlace = null;
                    _selectedPhotoData = null;
                  });
                }
              },
            ),

            // マップコントロール
            MapCircleMenu(
              onLocationPressed: _moveToCurrentLocation,
            ),

            // ローディングインジケーター
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(child: CircularProgressIndicator()),
              ),

            // 情報ウィンドウ
            if (_selectedPlace != null && _selectedPhotoData != null)
              Positioned(
                top: 20,
                left: 20,
                right: 20,
                child: FadeTransition(
                  opacity: _animation,
                  child: GestureDetector(
                    onTap: _navigateToPlaceDetail,
                    child: CustomInfoWindow(
                      name: _selectedPlace!['name'],
                      imageUrl: _selectedPhotoData!['image_url'],
                      favoriteCount: _selectedPlace!['favorite_count'],
                      rating: _selectedPlace!['rating']?.toString() ?? '未評価',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

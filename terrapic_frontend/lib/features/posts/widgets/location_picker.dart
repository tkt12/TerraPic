/// TerraPicアプリの場所選択ウィジェット
///
/// 投稿する場所の選択と写真スポットの指定を行うための
/// 地図ベースの選択インターフェースを提供する。
///
/// 主な機能:
/// - 場所の検索
/// - 地図上での場所選択
/// - 写真スポットの位置指定
/// - 選択した場所の確認と保存
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../../../core/config/app_config.dart';
import '../../places/models/place.dart';
import '../../../shared/widgets/base_layout.dart';

class LocationPicker extends StatefulWidget {
  final LatLng? geotagLocation;

  const LocationPicker({Key? key, this.geotagLocation}) : super(key: key);

  @override
  _LocationPickerState createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  final TextEditingController _searchController = TextEditingController();
  List<Place> _searchResults = [];
  Timer? _debounce;
  bool _isLoading = false;
  bool _isSearching = false;

  /// 場所を検索する
  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() {
      _isLoading = true;
      _isSearching = true;
    });

    try {
      final uri = Uri.parse('${AppConfig.backendUrl}/api/post_place_search/')
          .replace(queryParameters: {'q': query});

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _searchResults = data.map((place) => Place.fromJson(place)).toList();
        });
      } else {
        throw Exception('場所の検索に失敗しました');
      }
    } catch (e) {
      _showError('検索中にエラーが発生しました: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _isSearching = false;
      });
    }
  }

  /// エラーメッセージを表示
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// 検索入力の処理
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchPlaces(query);
    });
  }

  /// 選択した場所の写真スポット指定画面に遷移
  void _selectPlace(Place place) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhotoSpotPicker(
          place: place,
          geotagLocation: widget.geotagLocation,
        ),
      ),
    );

    if (result != null && result is Place) {
      Navigator.pop(context, result);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('場所を選択'),
      ),
      body: Column(
        children: [
          // 検索バー
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '場所を検索',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(14.0),
                        child: SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),

          // 検索結果リスト
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final place = _searchResults[index];
                      return ListTile(
                        leading: const Icon(Icons.place),
                        title: Text(place.name),
                        subtitle: place.formattedAddress != null
                            ? Text(
                                place.formattedAddress!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              )
                            : null,
                        onTap: () => _selectPlace(place),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// 写真スポットを選択するウィジェット
class PhotoSpotPicker extends StatefulWidget {
  final Place place;
  final LatLng? geotagLocation;

  const PhotoSpotPicker({
    Key? key,
    required this.place,
    this.geotagLocation,
  }) : super(key: key);

  @override
  _PhotoSpotPickerState createState() => _PhotoSpotPickerState();
}

class _PhotoSpotPickerState extends State<PhotoSpotPicker> {
  GoogleMapController? _mapController;
  late LatLng _selectedLocation;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    // 優先順位:
    // 1. ジオタグから取得した位置情報
    // 2. 既に撮影位置が設定されている場合
    // 3. 場所の基準座標
    if (widget.geotagLocation != null) {
      _selectedLocation = widget.geotagLocation!;
      // ジオタグから位置を取得した場合は通知
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('写真のジオタグから撮影場所を自動設定しました'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      });
    } else if (widget.place.hasPhotoSpot) {
      _selectedLocation = LatLng(
        widget.place.photoSpotLatitude!,
        widget.place.photoSpotLongitude!,
      );
    } else {
      _selectedLocation = LatLng(widget.place.latitude, widget.place.longitude);
    }

    _addMarker(_selectedLocation);
  }

  /// マーカーを追加
  void _addMarker(LatLng position) {
    if (kDebugMode) {
      debugPrint('Adding marker at position: $position');
    }
    setState(() {
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('photo_spot'),
          position: position,
          draggable: true,
          onDragEnd: (newPosition) {
            if (kDebugMode) {
              debugPrint('Marker dragged to: $newPosition');
            }
            setState(() => _selectedLocation = newPosition);
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseLayout(
      // BaseLayoutでラップ
      showBottomBar: false, // ボトムナビゲーションバーを非表示
      appBar: AppBar(
        title: const Text('撮影場所を指定'),
      ),
      child: Stack(
        // child属性にScaffoldの中身を移動
        children: [
          // 地図表示
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _selectedLocation,
              zoom: 18,
            ),
            onMapCreated: (controller) => _mapController = controller,
            markers: _markers,
            onTap: (position) {
              if (kDebugMode) {
                debugPrint('Map tapped at: $position');
              }
              _addMarker(position);
              _selectedLocation = position; // 位置を更新
            },
          ),
          // 説明テキスト
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  widget.geotagLocation != null
                      ? '写真のジオタグから撮影場所を自動設定しました。\n'
                          '必要に応じてマーカーをドラッグまたは地図をタップして調整できます。'
                      : '写真を撮影した位置を指定してください。\n'
                          'マーカーをドラッグするか、地図をタップして位置を指定できます。',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ),
            ),
          ),
          // 下部のボタンを配置
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: SafeArea(
                child: ElevatedButton(
                  onPressed: () {
                    if (kDebugMode) {
                      debugPrint('Selected photo spot location: $_selectedLocation');
                      debugPrint('Original place: ${widget.place}');
                    }
                    final updatedPlace = widget.place.copyWithPhotoSpot(
                      photoSpotLatitude: _selectedLocation.latitude,
                      photoSpotLongitude: _selectedLocation.longitude,
                    );
                    if (kDebugMode) {
                      debugPrint('Updated place: $updatedPlace');
                    }
                    Navigator.pop(context, updatedPlace);
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('撮影場所を確定'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

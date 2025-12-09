/// TerraPicアプリの場所詳細画面
///
/// 選択された場所の詳細情報を表示する。
/// 写真一覧、評価、お気に入り機能などを提供する。
///
/// 主な機能:
/// - 基本情報の表示
/// - 写真一覧の表示
/// - 評価とレビュー
/// - お気に入り登録
/// - 写真スポットの表示
///
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';

import '../../../core/config/app_config.dart';
import '../../../features/auth/services/auth_service.dart';
import '../../posts/screens/post_detail_screen.dart';
import '../../posts/widgets/posts_grid.dart';
import '../../../shared/widgets/base_layout.dart';
import '../../../shared/utils/error_handler.dart';
import '../../posts/utils/post_normalizer.dart';
import '../widgets/place_rating_section.dart';

class PlaceDetailScreen extends StatefulWidget {
  final Map<String, dynamic> place;
  final int? highlightedPostId;

  const PlaceDetailScreen({
    Key? key,
    required this.place,
    this.highlightedPostId,
  }) : super(key: key);

  @override
  _PlaceDetailScreenState createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _placeDetails;
  bool _isLoading = true;
  bool _isFavorite = false;
  bool _isProcessing = false;
  final Map<String, Future<void>> _imagePreloadFutures = {};

  @override
  void initState() {
    super.initState();
    _fetchPlaceDetails();
    _checkFavoriteStatus();
  }

  /// 場所の詳細情報を取得
  Future<void> _fetchPlaceDetails() async {
    try {
      final response = await http.get(
        Uri.parse(
            '${AppConfig.backendUrl}/api/places/${widget.place['id']}/details/'),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decodedData = json.decode(utf8.decode(response.bodyBytes));

        // 写真データに場所情報を追加
        if (decodedData['photos'] != null) {
          final photos = List<Map<String, dynamic>>.from(decodedData['photos']);
          for (var photo in photos) {
            photo['place'] = {
              'id': widget.place['id'],
              'name': decodedData['name'] ?? widget.place['name'],
            };
          }
          decodedData['photos'] = photos;
        }

        setState(() {
          _placeDetails = decodedData;
          _isLoading = false;
        });
      } else {
        ErrorHandler.showError(context, '詳細情報の取得に失敗しました');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.showError(context, 'エラーが発生しました');
      setState(() => _isLoading = false);
    }
  }

  /// お気に入り状態を確認
  Future<void> _checkFavoriteStatus() async {
    try {
      final response = await _authService.authenticatedRequest(
        '/api/places/${widget.place['id']}/favorite/status/',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _isFavorite = data['is_favorite'] ?? false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error checking favorite status: $e');
      }
    }
  }

  /// お気に入り状態を切り替え
  Future<void> _toggleFavorite() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final response = await _authService.authenticatedRequest(
        '/api/places/${widget.place['id']}/favorite/',
        method: 'POST',
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _isFavorite = data['status'] == 'favorited';
          if (_placeDetails != null) {
            _placeDetails!['favorite_count'] = data['favorite_count'];
          }
        });
      } else {
        ErrorHandler.showError(context, 'お気に入りの更新に失敗しました');
      }
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.showError(context, 'エラーが発生しました');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  /// 投稿写真をタップした時の処理
  Future<void> _navigateToPostDetail(Map<String, dynamic> post) async {
    if (_placeDetails == null || _placeDetails!['photos'] == null) return;

    try {
      final posts = List<Map<String, dynamic>>.from(_placeDetails!['photos']);

      // 場所の情報を各投稿に追加
      final postsWithPlace = posts.map((post) {
        return {
          ...post,
          'place': {
            'id': widget.place['id'],
            'name': _placeDetails?['name'] ?? widget.place['name'],
          },
        };
      }).toList();

      // 投稿リストを正規化
      final normalizedPosts = PostNormalizer.normalizeList(
        postsWithPlace, // 場所情報を追加した投稿リストを使用
        AppConfig.backendUrl,
      );

      // 選択された投稿のインデックスを取得
      final selectedIndex = normalizedPosts.indexWhere((p) =>
          p['id'] ==
          (post['id'] is int ? post['id'] : int.parse(post['id'].toString())));

      if (selectedIndex == -1) {
        throw Exception('Post not found in normalized list');
      }

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PostDetailScreen(
            posts: normalizedPosts,
            postId: post['id'] is int
                ? post['id']
                : int.parse(post['id'].toString()),
            placeName: _placeDetails?['name'] ?? widget.place['name'],
            selectedIndex: selectedIndex,
            heroTag: 'place_${widget.place['id']}_${post['id']}',
            cachedImages: _imagePreloadFutures,
            source: 'place',
          ),
        ),
      );

      // 編集・削除が行われた場合はデータを再読み込み
      if (result == true && mounted) {
        await _loadPlaceDetails();
      }
    } catch (e) {
      ErrorHandler.showError(context, 'エラーが発生しました: $e');
      if (kDebugMode) {
        debugPrint('Error in _navigateToPostDetail: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseLayout(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverAppBar(
                      expandedHeight: 200,
                      pinned: true,
                      stretch: true,
                      flexibleSpace: FlexibleSpaceBar(
                        stretchModes: const [
                          StretchMode.zoomBackground,
                          StretchMode.blurBackground,
                        ],
                        title: Text(
                          _placeDetails?['name'] ?? widget.place['name'],
                          style: const TextStyle(
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
                        background: Stack(
                          fit: StackFit.expand,
                          children: [
                            _placeDetails?['image_url'] != null
                                ? Image.network(
                                    _placeDetails!['image_url'],
                                    fit: BoxFit.cover,
                                  )
                                : Container(color: Colors.blue),
                            // スクロール時のぼかし効果のオーバーレイ
                            innerBoxIsScrolled
                                ? ClipRect(
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                        sigmaX: 5,
                                        sigmaY: 5,
                                      ),
                                      child: Container(
                                        color: Colors.white.withOpacity(0.5),
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ],
                        ),
                      ),
                      actions: [
                        IconButton(
                          icon: Icon(
                            _isFavorite
                                ? Icons.bookmark
                                : Icons.bookmark_outline,
                            color: _isFavorite ? Colors.blue : Colors.white,
                          ),
                          onPressed: _isProcessing ? null : _toggleFavorite,
                        ),
                      ],
                    ),
                  ];
                },
                // メインコンテンツ
                body: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PlaceRatingSection(placeDetails: _placeDetails),
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              '写真一覧',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 写真グリッド
                    SliverToBoxAdapter(
                      child: _placeDetails?['photos'] != null &&
                              (_placeDetails?['photos'] as List).isNotEmpty
                          ? Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: PostsGrid(
                                posts: List<Map<String, dynamic>>.from(
                                    _placeDetails!['photos']),
                                hasNextPage: false,
                                isLoading: false,
                                emptyMessage: '写真がありません',
                                onRefresh: _fetchPlaceDetails,
                                onPostTap: _navigateToPostDetail,
                                gridType: 'place_detail',
                              ),
                            )
                          : Container(
                              padding: const EdgeInsets.all(32),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.photo_library_outlined,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      '写真がありません',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

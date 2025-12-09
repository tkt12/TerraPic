/// TerraPicアプリの写真詳細画面
///
/// 投稿写真の詳細情報を表示する画面。
/// データソースに依存しない統一された表示を提供する。
///
/// 主な機能:
/// - 写真の表示
/// - 投稿情報の表示（説明文、投稿日時など）
/// - いいね機能
/// - 撮影場所への経路案内
/// - ユーザープロフィールへの遷移
/// - アニメーション付きのいいね表示
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/widgets/base_layout.dart';
import '../../../shared/utils/date_formatter.dart';
import '../../../shared/utils/hero_tag_generator.dart';
import '../../../shared/utils/error_handler.dart';
import '../../../features/auth/services/auth_service.dart';
import '../../../features/profile/screens/profile_screen.dart';
import '../../../features/profile/screens/profile_user_screen.dart';
import '../../../features/places/screens/place_detail_screen.dart';
import 'post_edit_screen.dart';

class PostDetailScreen extends StatefulWidget {
  final List<Map<String, dynamic>> posts;
  final int postId;
  final String placeName;
  final int selectedIndex;
  final String heroTag;
  final Map<String, Future<void>> cachedImages;
  final String source;
  final String? searchQuery;

  const PostDetailScreen({
    Key? key,
    required this.posts,
    required this.postId,
    required this.placeName,
    required this.selectedIndex,
    required this.heroTag,
    required this.cachedImages,
    required this.source,
    this.searchQuery,
  }) : super(key: key);

  @override
  _PostDetailScreenState createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen>
    with SingleTickerProviderStateMixin {
  // スクロール制御
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _itemKeys = [];

  // 状態管理
  bool _isCalculatingHeights = true;
  bool _hasCalculatedHeights = false;

  // サービス
  final AuthService _authService = AuthService();

  // 現在のユーザーID
  String? _currentUserId;

  // いいね状態の管理
  Map<int, bool> _likeStates = {};
  Map<int, int> _likeCounts = {};

  // ダブルタップアニメーション
  Map<int, bool> _showDoubleTapLike = {};
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  // 正規化された投稿データ
  late List<Map<String, dynamic>> _normalizedPosts;

  @override
  void initState() {
    super.initState();
    // 投稿データの受け取りをそのまま使用（再正規化しない）
    _normalizedPosts = widget.posts;

    if (kDebugMode) {
      debugPrint('Initial normalized posts:');
      _normalizedPosts.take(3).forEach((p) => debugPrint('ID: ${p['id']}'));
    }

    // キーの生成
    _itemKeys
        .addAll(List.generate(_normalizedPosts.length, (index) => GlobalKey()));

    // アニメーションの初期化
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInBack,
      ),
    );

    // いいね状態の初期化
    for (var post in _normalizedPosts) {
      _fetchLikeStatus(post['id']);
      _showDoubleTapLike[post['id']] = false;
    }

    // 現在のユーザーIDを取得（同期的に実行）
    _initializeUserId();

    if (kDebugMode) {
      debugPrint('PostDetailScreen initialized with:');
      debugPrint('Selected Index: ${widget.selectedIndex}');
      debugPrint('Posts length: ${widget.posts.length}');
      debugPrint('First few posts:');
      widget.posts
          .take(3)
          .forEach((post) => debugPrint('Post ID: ${post['id']}'));
    }
  }

  /// 現在のユーザーIDを初期化
  Future<void> _initializeUserId() async {
    await _loadCurrentUserId();
  }

  /// 現在のユーザーIDを読み込む
  Future<void> _loadCurrentUserId() async {
    final userId = await _authService.getCurrentUserId();
    if (kDebugMode) {
      debugPrint('_loadCurrentUserId - User ID loaded: $userId');
    }
    if (mounted) {
      setState(() {
        _currentUserId = userId;
      });
      if (kDebugMode) {
        debugPrint('_loadCurrentUserId - State updated with User ID: $_currentUserId');
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasCalculatedHeights) {
      _hasCalculatedHeights = true;
      // ユーザーIDを確実に取得してから画面を表示
      if (_currentUserId == null) {
        _loadCurrentUserId().then((_) {
          if (mounted) {
            setState(() {
              _isCalculatingHeights = false;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToSelectedItem();
            });
          }
        });
      } else {
        setState(() {
          _isCalculatingHeights = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToSelectedItem();
        });
      }
    }
  }

  /// いいね状態を取得
  Future<void> _fetchLikeStatus(int postId) async {
    try {
      final response = await _authService.authenticatedRequest(
        '/api/post/$postId/like/status/',
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _likeStates[postId] = data['is_liked'];
          _likeCounts[postId] = data['like_count'];
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching like status: $e');
      }
    }
  }

  /// 選択された投稿までスクロール
  void _scrollToSelectedItem() {
    if (!mounted || widget.selectedIndex >= _itemKeys.length) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _itemKeys[widget.selectedIndex];
      final context = key.currentContext;
      if (context == null) return;

      final box = context.findRenderObject() as RenderBox?;
      if (box == null) return;

      final position = box.localToGlobal(Offset.zero);

      if (_scrollController.hasClients) {
        final appBarHeight = AppBar().preferredSize.height;
        final statusBarHeight = MediaQuery.of(context).padding.top;
        final screenHeight = MediaQuery.of(context).size.height;

        // スクロールの最大位置を計算
        final maxScroll = _scrollController.position.maxScrollExtent;

        // 計算されたスクロール位置
        final calculatedOffset = _scrollController.offset +
            position.dy -
            (appBarHeight + statusBarHeight + 55);

        // 最後の投稿の場合は不要なスクロールを防ぐ
        if (widget.selectedIndex == _itemKeys.length - 1) {
          // 最後の投稿が画面に収まる場合はスクロールしない
          if (position.dy + box.size.height < screenHeight) {
            return;
          }
        }

        // スクロール位置を制限
        _scrollController
            .jumpTo(math.min(maxScroll, math.max(0, calculatedOffset)));
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseLayout(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            _getScreenTitle(),
            style: const TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: _isCalculatingHeights
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  children: _normalizedPosts.map((post) {
                    final index = _normalizedPosts.indexOf(post);
                    return Container(
                      key: _itemKeys[index],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildUserHeader(post),
                          _buildPostImage(post, post['id']),
                          _buildActionButtons(post, post['id']),
                          _buildPostInfo(post),
                          const SizedBox(height: 16),
                          const Divider(height: 1),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
      ),
    );
  }

  String _getScreenTitle() {
    switch (widget.source) {
      case 'place':
        return widget.placeName;
      case 'search':
        return '検索: "${widget.searchQuery ?? ''}"';
      case 'posts':
        return '投稿';
      default:
        return 'いいね';
    }
  }

  Widget _buildUserHeader(Map<String, dynamic> post) {
    final user = post['user'];
    // 現在のユーザーが投稿の所有者かどうかを確認
    final isOwner = _currentUserId != null &&
        user['id'] != null &&
        user['id'].toString() == _currentUserId;

    if (kDebugMode) {
      debugPrint('_buildUserHeader - Post ID: ${post['id']}');
      debugPrint('  Current User ID: $_currentUserId');
      debugPrint('  Post User ID: ${user['id']}');
      debugPrint('  Is Owner: $isOwner');
    }

    return ListTile(
      leading: GestureDetector(
        onTap: () => _navigateToUserProfile(user),
        child: CircleAvatar(
          backgroundImage: user['profile_image'] != null
              ? NetworkImage(user['profile_image'])
              : null,
          child:
              user['profile_image'] == null ? const Icon(Icons.person) : null,
        ),
      ),
      title: GestureDetector(
        onTap: () => _navigateToUserProfile(user),
        child: Text(
          user['username'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      subtitle: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlaceDetailScreen(
                place: {
                  'id': post['place']['id'],
                  'name': post['place']['name'],
                },
              ),
            ),
          );
        },
        child: Text(
          post['place']['name'],
        ),
      ),
      trailing: isOwner
          ? IconButton(
              icon: const Icon(Icons.more_horiz),
              onPressed: () => _showPostMenu(context, post),
            )
          : null,
    );
  }

  Widget _buildPostImage(Map<String, dynamic> post, int postId) {
    return GestureDetector(
      onDoubleTap: () {
        if (!(_likeStates[postId] ?? false)) {
          _toggleLike(postId);
        }
        _showLikeAnimation(postId);
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Hero(
            tag: post['_hero_tag'] ??
                HeroTagGenerator.generatePostTag(
                  source: widget.source,
                  postId: postId,
                  index: _normalizedPosts.indexWhere((p) => p['id'] == postId),
                ),
            child: Image.network(
              post['image_url'],
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                if (kDebugMode) {
                  debugPrint('Image error: $error');
                }
                return const Center(child: Icon(Icons.error));
              },
            ),
          ),
          if (_showDoubleTapLike[postId] ?? false)
            ScaleTransition(
              scale: _scaleAnimation,
              child: const Icon(Icons.favorite, color: Colors.red, size: 100),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> post, int postId) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _likeStates[postId] ?? false
                  ? Icons.favorite
                  : Icons.favorite_border,
              color: _likeStates[postId] ?? false ? Colors.red : null,
            ),
            onPressed: () => _toggleLike(postId),
          ),
          Text(
            '${_likeCounts[postId] ?? post['like_count']}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          if (post['photo_spot_location'] != null)
            IconButton(
              icon: const Icon(Icons.directions, color: Colors.blue, size: 28),
              onPressed: () => _openGoogleMaps(post),
              tooltip: '撮影地点までの経路を表示',
            ),
        ],
      ),
    );
  }

  /// 投稿情報を構築
  Widget _buildPostInfo(Map<String, dynamic> post) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post['description']?.isNotEmpty ?? false)
            Text(post['description']),
          const SizedBox(height: 4),
          Text(
            DateFormatter.formatDateTime(DateTime.parse(post['created_at'])),
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// いいねを切り替え
  Future<void> _toggleLike(int postId) async {
    setState(() {
      _likeStates[postId] = !(_likeStates[postId] ?? false);
      _likeCounts[postId] =
          (_likeCounts[postId] ?? 0) + (_likeStates[postId]! ? 1 : -1);
    });

    try {
      final response = await _authService.authenticatedRequest(
        '/api/post/$postId/like/',
        method: 'POST',
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _likeStates[postId] = data['status'] == 'liked';
          _likeCounts[postId] = data['like_count'];
        });
      } else {
        _revertLikeState(postId);
        ErrorHandler.showError(context, 'いいねの更新に失敗しました');
      }
    } catch (e) {
      if (!mounted) return;
      _revertLikeState(postId);
      ErrorHandler.showError(context, 'エラーが発生しました');
    }
  }

  /// いいね状態を元に戻す
  void _revertLikeState(int postId) {
    setState(() {
      _likeStates[postId] = !(_likeStates[postId] ?? false);
      _likeCounts[postId] =
          (_likeCounts[postId] ?? 0) + (_likeStates[postId]! ? 1 : -1);
    });
  }

  /// いいねアニメーションを表示
  void _showLikeAnimation(int postId) {
    setState(() => _showDoubleTapLike[postId] = true);
    _animationController.forward().then((_) {
      _animationController.reverse().then((_) {
        if (mounted) setState(() => _showDoubleTapLike[postId] = false);
      });
    });
  }

  /// Google Mapsで経路を表示
  Future<void> _openGoogleMaps(Map<String, dynamic> post) async {
    try {
      final photoSpotLocation = post['photo_spot_location'];
      if (photoSpotLocation == null ||
          photoSpotLocation['coordinates'] == null) {
        ErrorHandler.showError(context, '撮影地点の情報がありません');
        return;
      }

      final coordinates = photoSpotLocation['coordinates'] as List;
      final longitude = coordinates[0].toDouble();
      final latitude = coordinates[1].toDouble();
      final name = Uri.encodeComponent(widget.placeName);

      final Uri appUrl = Uri.parse(
          'comgooglemaps://?daddr=$latitude,$longitude&datitle=$name&directionsmode=driving');

      if (await launchUrl(appUrl, mode: LaunchMode.externalApplication)) return;

      final Uri browserUrl = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&destination_name=$name&travelmode=driving');

      if (!await launchUrl(browserUrl, mode: LaunchMode.externalApplication)) {
        ErrorHandler.showError(context, 'Google マップを開けませんでした');
      }
    } catch (e) {
      ErrorHandler.showError(context, 'エラーが発生しました');
    }
  }

  /// ユーザープロフィール画面に遷移
  Future<void> _navigateToUserProfile(Map<String, dynamic> user) async {
    final currentUserId = await _authService.getCurrentUserId();
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => user['id'].toString() == currentUserId
            ? const ProfileScreen()
            : UserProfileScreen(
                userId: user['id'].toString(),
                username: user['username'],
              ),
      ),
    );
  }

  /// 投稿メニューを表示
  void _showPostMenu(BuildContext context, Map<String, dynamic> post) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('編集'),
              onTap: () {
                Navigator.pop(context);
                _handleEditPost(post);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('削除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _handleDeletePost(post);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 投稿を編集する
  Future<void> _handleEditPost(Map<String, dynamic> post) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostEditScreen(post: post),
      ),
    );

    // 編集が成功した場合、投稿データを再取得して画面を更新
    if (result == true && mounted) {
      await _refreshPostData(post['id']);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('投稿が更新されました')),
      );
    }
  }

  /// 投稿データを再取得して更新
  Future<void> _refreshPostData(int postId) async {
    try {
      final response = await _authService.authenticatedRequest(
        '/api/post/$postId/like/status/',
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final updatedPost = data['post'];

        // リスト内の該当投稿を更新
        final index = _normalizedPosts.indexWhere((p) => p['id'] == postId);
        if (index != -1) {
          setState(() {
            _normalizedPosts[index] = {
              ..._normalizedPosts[index],
              'description': updatedPost['description'],
              'rating': updatedPost['rating'],
              'weather': updatedPost['weather'],
              'season': updatedPost['season'],
            };
            _likeStates[postId] = data['is_liked'];
            _likeCounts[postId] = data['like_count'];
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error refreshing post data: $e');
      }
    }
  }

  /// 投稿を削除する
  Future<void> _handleDeletePost(Map<String, dynamic> post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('投稿を削除'),
        content: const Text('この投稿を削除してもよろしいですか？\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final response = await _authService.authenticatedRequest(
        '/api/post/${post['id']}/delete/',
        method: 'DELETE',
      );

      if (!mounted) return;

      if (response.statusCode == 204) {
        // リストから削除された投稿を除外
        setState(() {
          _normalizedPosts.removeWhere((p) => p['id'] == post['id']);
        });

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('投稿を削除しました')),
        );

        // 投稿が全て削除された場合は画面を閉じる
        if (_normalizedPosts.isEmpty) {
          Navigator.of(context).pop(true);
        }
      } else {
        ErrorHandler.showError(context, '投稿の削除に失敗しました');
      }
    } catch (e) {
      if (!mounted) return;
      if (kDebugMode) {
        debugPrint('Error deleting post: $e');
      }
      ErrorHandler.showError(context, 'エラーが発生しました');
    }
  }
}

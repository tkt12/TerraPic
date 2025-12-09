/// TerraPicアプリのユーザープロフィール画面
///
/// 他のユーザーのプロフィールを表示する画面。
/// プロフィール情報の表示、投稿一覧の表示、フォロー機能を提供する。
///
/// 主な機能:
/// - プロフィール情報の表示
/// - 投稿一覧の表示
/// - フォロー/アンフォロー
/// - タブによる表示切り替え
///
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../shared/widgets/base_layout.dart';
import '../models/profile.dart';
import '../widgets/profile_header.dart';
import '../../posts/widgets/posts_grid.dart';
import '../../../features/auth/services/auth_service.dart';
import '../../posts/screens/post_detail_screen.dart';
import '../../posts/utils/post_normalizer.dart';
import '../../../core/config/app_config.dart';

/// スクロール可能なコンテンツをラップするウィジェット
class ScrollableContent extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;

  const ScrollableContent({
    Key? key,
    required this.child,
    required this.onRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        if (notification.depth == 0 &&
            notification is ScrollUpdateNotification) {
          if (notification.scrollDelta! > 0) {
            return false;
          }
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: true,
              fillOverscroll: true,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String username;

  const UserProfileScreen({
    Key? key,
    required this.userId,
    required this.username,
  }) : super(key: key);

  @override
  _UserProfileScreenState createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late TabController _tabController;

  // プロフィールデータ
  Profile? _profile;
  List<Map<String, dynamic>> _posts = [];

  // ローディング状態
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isFollowing = false;
  bool _isProcessingFollow = false;

  // ページネーション
  int _currentPage = 1;
  bool _hasNextPage = true;

  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    _loadUserProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// ユーザープロフィールを読み込む
  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);

    try {
      final response = await _authService.authenticatedRequest(
        '/api/users/${widget.userId}/',
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));

        setState(() {
          _profile = Profile.fromJson(data['profile']);
          _posts = List<Map<String, dynamic>>.from(data['posts']);
          _isFollowing = data['is_following'] ?? false;
          _hasNextPage = data['has_next'] ?? false;
          _isLoading = false;
          _errorMessage = '';
        });
      } else {
        throw Exception('プロフィールの取得に失敗しました');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'プロフィールの読み込みに失敗しました';
      });
    }
  }

  /// 追加の投稿を読み込む
  Future<void> _loadMorePosts() async {
    if (!_hasNextPage || _isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final response = await _authService.authenticatedRequest(
        '/api/users/${widget.userId}/?page=${_currentPage + 1}',
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final newPosts = List<Map<String, dynamic>>.from(data['posts']);

        setState(() {
          _posts.addAll(newPosts);
          _hasNextPage = data['has_next'] ?? false;
          _currentPage++;
          _isLoadingMore = false;
        });
      } else {
        throw Exception('投稿の取得に失敗しました');
      }
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
        _errorMessage = '投稿の読み込みに失敗しました';
      });
    }
  }

  /// フォロー状態を切り替える
  Future<void> _toggleFollow() async {
    if (_isProcessingFollow) return;

    setState(() => _isProcessingFollow = true);

    try {
      final response = await _authService.authenticatedRequest(
        '/api/users/${widget.userId}/follow',
        method: _isFollowing ? 'DELETE' : 'POST',
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _isFollowing = data['status'] == 'followed';
          if (_profile != null) {
            _profile = _profile!.copyWith(
              followerCount: data['follower_count'],
            );
          }
        });
      } else {
        _showError('フォロー操作に失敗しました');
      }
    } catch (e) {
      _showError(_isFollowing ? 'フォロー解除に失敗しました' : 'フォローに失敗しました');
    } finally {
      if (mounted) {
        setState(() => _isProcessingFollow = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _navigateToPostDetail(Map<String, dynamic> post) async {
    if (_profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('プロフィール情報の読み込みに失敗しました')),
      );
      return;
    }

    try {
      // 投稿リストを正規化
      final normalizedPosts = PostNormalizer.normalizeList(
        _posts,
        AppConfig.backendUrl,
      );

      // 投稿IDの正規化
      final int postId =
          post['id'] is int ? post['id'] : int.parse(post['id'].toString());

      // 選択された投稿のインデックスを取得
      final selectedIndex =
          normalizedPosts.indexWhere((p) => p['id'] == postId);

      if (selectedIndex == -1) {
        throw Exception('Post not found in normalized list');
      }

      // ヒーロータグの生成
      final String heroTag = 'user_profile_${widget.userId}_${postId}';

      if (!mounted) return;

      // 投稿詳細画面に遷移
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PostDetailScreen(
            posts: normalizedPosts,
            postId: postId,
            placeName: '@${_profile!.username}',
            selectedIndex: selectedIndex,
            heroTag: heroTag,
            cachedImages: {},
            source: 'posts',
          ),
        ),
      );

      // 編集・削除が行われた場合はデータを再読み込み
      if (result == true && mounted) {
        await _loadUserProfile();
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('エラーが発生しました: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      if (kDebugMode) {
        debugPrint('Error in _navigateToPostDetail: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseLayout(
      child: Scaffold(
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _profile == null
                ? Center(child: Text(_errorMessage))
                : SafeArea(
                    child: NestedScrollView(
                      physics: const ClampingScrollPhysics(),
                      headerSliverBuilder: (context, innerBoxIsScrolled) {
                        return <Widget>[
                          // プロフィールヘッダー
                          SliverToBoxAdapter(
                            child: ProfileHeader(
                              profile: _profile!,
                              isOwnProfile: false,
                              isFollowing: _isFollowing,
                              onFollowPressed:
                                  _isProcessingFollow ? null : _toggleFollow,
                            ),
                          ),
                          // タブバー
                          SliverPersistentHeader(
                            delegate: _SliverTabBarDelegate(
                              TabBar(
                                controller: _tabController,
                                labelColor: Colors.blue,
                                unselectedLabelColor: Colors.grey,
                                tabs: const [Tab(text: '投稿')],
                              ),
                            ),
                            pinned: true,
                          ),
                        ];
                      },
                      // 投稿一覧
                      body: TabBarView(
                        controller: _tabController,
                        children: [
                          ScrollableContent(
                            onRefresh: () async {
                              setState(() => _currentPage = 1);
                              await _loadUserProfile();
                            },
                            child: PostsGrid(
                              posts: _posts,
                              hasNextPage: _hasNextPage,
                              isLoading: _isLoadingMore,
                              emptyMessage: '投稿がありません',
                              onRefresh: _loadUserProfile,
                              onLoadMore: _loadMorePosts,
                              onPostTap: _navigateToPostDetail,
                              gridType: 'user_profile',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }
}

/// スライバータブバーのデリゲート
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverTabBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}

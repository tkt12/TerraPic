/// TerraPicアプリのプロフィール画面
///
/// ユーザー自身のプロフィールを表示する画面。
/// プロフィール情報、投稿一覧、いいねした投稿、お気に入りの場所を表示する。
///
/// 主な機能:
/// - プロフィール情報の表示
/// - 投稿一覧の表示
/// - いいねした投稿の表示
/// - お気に入りの場所の表示
/// - プロフィール編集
///
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:terrapic_frontend/core/config/app_config.dart';
import 'dart:convert';
import '../../../shared/widgets/base_layout.dart';
import '../models/profile.dart';
import '../widgets/profile_header.dart';
import '../../places/widgets/place_card.dart';
import '../../posts/widgets/posts_grid.dart';
import '../../../features/auth/services/auth_service.dart';
import 'profile_edit_screen.dart';
import '../../places/screens/place_detail_screen.dart';
import '../../posts/screens/post_detail_screen.dart';
import '../../posts/utils/post_normalizer.dart';

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

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverTabBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late TabController _tabController;

  // プロフィールデータ
  Profile? _profile;
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _likedPosts = [];
  List<Map<String, dynamic>> _favoritePlaces = [];

  // ローディング状態
  bool _isLoading = true;
  bool _isLoadingPosts = false;
  bool _isLoadingLikes = false;
  bool _isLoadingFavorites = false;

  // ページネーション
  int _postsPage = 1;
  int _likesPage = 1;
  int _favoritesPage = 1;
  bool _hasMorePosts = true;
  bool _hasMoreLikes = true;
  bool _hasMoreFavorites = true;

  // 画像のプリロード用のMap
  final Map<String, Future<void>> _imagePreloadFutures = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfileData();
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  /// タブ切り替え時の処理
  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      switch (_tabController.index) {
        case 0:
          if (_posts.isEmpty && !_isLoading) {
            _loadProfileData();
          }
          break;
        case 1:
          if (_likedPosts.isEmpty && !_isLoadingLikes) {
            _loadLikedPosts();
          }
          break;
        case 2:
          if (_favoritePlaces.isEmpty && !_isLoadingFavorites) {
            _loadFavoritePlaces();
          }
          break;
      }
    }
  }

  /// プロフィールデータを読み込む
  Future<void> _loadProfileData() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      // トークンの確認
      final token = await _authService.getAccessToken();
      if (kDebugMode) {
        debugPrint('Loading profile with token: $token');
      }

      // 3つのAPIリクエストを並列で実行
      final results = await Future.wait([
        _authService.authenticatedRequest('/api/profile/'),
        _authService.authenticatedRequest('/api/profile/likes/?page=1'),
        _authService.authenticatedRequest('/api/profile/favorites/?page=1'),
      ]);

      if (!mounted) return;

      // プロフィールデータの処理
      if (results[0].statusCode == 200) {
        final profileData = json.decode(utf8.decode(results[0].bodyBytes));
        _profile = Profile.fromJson(profileData['profile']);
        _posts = List<Map<String, dynamic>>.from(profileData['posts']);
        _hasMorePosts = profileData['has_next'] ?? false;
        _postsPage = 1;
      } else if (results[0].statusCode == 401) {
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }

      // いいねデータの処理
      if (results[1].statusCode == 200) {
        final likesData = json.decode(utf8.decode(results[1].bodyBytes));
        _likedPosts = List<Map<String, dynamic>>.from(likesData['posts']);
        _hasMoreLikes = likesData['has_next'] ?? false;
        _likesPage = 1;
      }

      // お気に入りデータの処理
      if (results[2].statusCode == 200) {
        final favoritesData = json.decode(utf8.decode(results[2].bodyBytes));
        _favoritePlaces =
            List<Map<String, dynamic>>.from(favoritesData['places']);
        _hasMoreFavorites = favoritesData['has_next'] ?? false;
        _favoritesPage = 1;
      }

      setState(() {
        _isLoading = false;
        _isLoadingLikes = false;
        _isLoadingFavorites = false;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading profile data: $e');
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _profile = null;
          _isLoadingLikes = false;
          _isLoadingFavorites = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('データの読み込みに失敗しました: $e')),
        );
      }
    }
  }

  /// 投稿をさらに読み込む
  Future<void> _loadMorePosts() async {
    if (!_hasMorePosts || _isLoadingPosts) return;

    setState(() => _isLoadingPosts = true);

    try {
      final response = await _authService
          .authenticatedRequest('/api/profile/?page=${_postsPage + 1}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _posts.addAll(List<Map<String, dynamic>>.from(data['posts']));
          _hasMorePosts = data['has_next'] ?? false;
          _postsPage++;
          _isLoadingPosts = false;
        });
      } else {
        throw Exception('投稿の取得に失敗しました');
      }
    } catch (e) {
      if (!mounted) return;
      _showError('投稿の読み込みに失敗しました');
      setState(() => _isLoadingPosts = false);
    }
  }

  /// いいねした投稿を読み込む
  Future<void> _loadLikedPosts() async {
    if (_isLoadingLikes) return;

    setState(() => _isLoadingLikes = true);

    try {
      final response = await _authService
          .authenticatedRequest('/api/profile/likes/?page=$_likesPage');

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          if (_likesPage == 1) {
            _likedPosts = List<Map<String, dynamic>>.from(data['posts']);
          } else {
            _likedPosts.addAll(List<Map<String, dynamic>>.from(data['posts']));
          }
          _hasMoreLikes = data['has_next'] ?? false;
          _isLoadingLikes = false;
        });
      } else {
        throw Exception('いいねした投稿の取得に失敗しました');
      }
    } catch (e) {
      if (!mounted) return;
      _showError('いいねした投稿の読み込みに失敗しました');
      setState(() => _isLoadingLikes = false);
    }
  }

  /// お気に入りの場所を読み込む
  Future<void> _loadFavoritePlaces() async {
    if (_isLoadingFavorites) return;

    setState(() => _isLoadingFavorites = true);

    try {
      final response = await _authService
          .authenticatedRequest('/api/profile/favorites/?page=$_favoritesPage');

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          if (_favoritesPage == 1) {
            _favoritePlaces = List<Map<String, dynamic>>.from(data['places']);
          } else {
            _favoritePlaces
                .addAll(List<Map<String, dynamic>>.from(data['places']));
          }
          _hasMoreFavorites = data['has_next'] ?? false;
          _isLoadingFavorites = false;
        });
      } else {
        throw Exception('お気に入りの場所の取得に失敗しました');
      }
    } catch (e) {
      if (!mounted) return;
      _showError('お気に入りの場所の読み込みに失敗しました');
      setState(() => _isLoadingFavorites = false);
    }
  }

  /// エラーメッセージを表示
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// 写真詳細画面に遷移
  Future<void> _navigateToPostDetail(
    Map<String, dynamic> post,
    String source,
  ) async {
    if (_profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('プロフィール情報の読み込みに失敗しました')),
      );
      return;
    }

    try {
      // ソースに基づいて適切な投稿リストを選択
      final List<Map<String, dynamic>> sourceList = switch (source) {
        'posts' => _posts,
        'likes' => _likedPosts,
        _ => throw ArgumentError('Invalid source: $source'),
      };

      // 投稿リストを正規化
      final normalizedPosts = PostNormalizer.normalizeList(
        sourceList,
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
      final String heroTag = 'profile_${_profile!.id}_${postId}_$source';

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
            cachedImages: _imagePreloadFutures,
            source: source,
          ),
        ),
      );

      // 編集・削除が行われた場合はデータを再読み込み
      if (result == true && mounted) {
        await _loadProfileData();
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
                ? const Center(child: Text('プロフィールの読み込みに失敗しました'))
                : SafeArea(
                    child: NestedScrollView(
                      physics: const ClampingScrollPhysics(),
                      headerSliverBuilder: (context, innerBoxIsScrolled) {
                        return <Widget>[
                          SliverToBoxAdapter(
                            child: ProfileHeader(
                              profile: _profile!,
                              isOwnProfile: true,
                              onEditPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        ProfileEditScreen(profile: _profile!),
                                  ),
                                );
                                if (result == true) {
                                  _loadProfileData();
                                }
                              },
                            ),
                          ),
                          SliverPersistentHeader(
                            delegate: _SliverTabBarDelegate(
                              TabBar(
                                controller: _tabController,
                                labelColor: Colors.blue,
                                unselectedLabelColor: Colors.grey,
                                tabs: const [
                                  Tab(text: '投稿'),
                                  Tab(text: 'いいね'),
                                  Tab(text: 'お気に入り'),
                                ],
                              ),
                            ),
                            pinned: true,
                          ),
                        ];
                      },
                      body: TabBarView(
                        controller: _tabController,
                        children: [
                          ScrollableContent(
                            onRefresh: () async {
                              setState(() => _postsPage = 1);
                              await _loadProfileData();
                            },
                            child: PostsGrid(
                              posts: _posts,
                              hasNextPage: _hasMorePosts,
                              isLoading: _isLoadingPosts,
                              emptyMessage: '投稿がありません',
                              onRefresh: () async {
                                setState(() => _postsPage = 1);
                                await _loadProfileData();
                              },
                              onLoadMore: _loadMorePosts,
                              onPostTap: (post) =>
                                  _navigateToPostDetail(post, 'posts'),
                              gridType: 'profile_posts',
                            ),
                          ),
                          ScrollableContent(
                            onRefresh: () async {
                              setState(() => _likesPage = 1);
                              await _loadLikedPosts();
                            },
                            child: PostsGrid(
                              posts: _likedPosts,
                              hasNextPage: _hasMoreLikes,
                              isLoading: _isLoadingLikes,
                              emptyMessage: 'いいねした投稿がありません',
                              onRefresh: () async {
                                setState(() => _likesPage = 1);
                                await _loadLikedPosts();
                              },
                              onLoadMore: _loadLikedPosts,
                              onPostTap: (post) =>
                                  _navigateToPostDetail(post, 'likes'),
                              gridType: 'profile_likes',
                            ),
                          ),
                          ScrollableContent(
                            onRefresh: () async {
                              setState(() => _favoritesPage = 1);
                              await _loadFavoritePlaces();
                            },
                            child: _isLoadingFavorites
                                ? const Center(
                                    child: CircularProgressIndicator())
                                : _favoritePlaces.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.place,
                                              size: 64,
                                              color: Colors.grey[400],
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              'お気に入りした場所がありません',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : ListView.builder(
                                        padding: EdgeInsets.zero,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        shrinkWrap: true,
                                        itemCount: _favoritePlaces.length +
                                            (_hasMoreFavorites ? 1 : 0),
                                        itemBuilder: (context, index) {
                                          if (index < _favoritePlaces.length) {
                                            return PlaceCard(
                                              place: _favoritePlaces[index],
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        PlaceDetailScreen(
                                                      place: _favoritePlaces[
                                                          index],
                                                    ),
                                                  ),
                                                );
                                              },
                                            );
                                          } else {
                                            return _isLoadingFavorites
                                                ? const Center(
                                                    child: Padding(
                                                      padding:
                                                          EdgeInsets.all(16.0),
                                                      child:
                                                          CircularProgressIndicator(),
                                                    ),
                                                  )
                                                : const SizedBox.shrink();
                                          }
                                        },
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

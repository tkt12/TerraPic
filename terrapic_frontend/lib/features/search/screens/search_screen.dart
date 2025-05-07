/// TerraPicアプリの検索画面
///
/// 場所、投稿、ユーザーの検索機能を提供する。
/// リアルタイムの検索結果表示と、検索結果の種類別の表示を行う。
///
/// 主な機能:
/// - キーワード検索
/// - 場所の検索と表示
/// - 投稿の検索と表示
/// - ユーザーの検索と表示
/// - 検索結果のリアルタイム更新
///
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:terrapic_frontend/features/main/screens/main_screen.dart';
import 'dart:convert';
import 'dart:async';

import '../../../core/config/app_config.dart';
import '../../../shared/widgets/base_layout.dart';
import '../../../shared/utils/hero_tag_generator.dart';
import '../../../features/posts/widgets/posts_grid.dart';
import '../../../features/profile/screens/profile_screen.dart';
import '../../../features/profile/screens/profile_user_screen.dart';
import '../../../features/places/screens/place_detail_screen.dart';
import '../../../features/posts/screens/post_detail_screen.dart';
import '../../../features/auth/services/auth_service.dart';
import '../../posts/utils/post_normalizer.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final AuthService _authService = AuthService();
  Map<String, dynamic> _searchResults = {};
  bool _isLoading = false;
  Timer? _debounceTimer;

  // 画像のプリロード用のMap
  final Map<String, Future<void>> _imagePreloadFutures = {};

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// 検索を実行
  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = {});
      return;
    }

    setState(() => _isLoading = true);

    try {
      final url = Uri.parse('${AppConfig.backendUrl}/api/search/')
          .replace(queryParameters: {'q': query});

      final response = await http.get(url);

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _searchResults = json.decode(utf8.decode(response.bodyBytes));
          _isLoading = false;
        });
      } else {
        throw Exception('検索に失敗しました (${response.statusCode})');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('検索中にエラーが発生しました');
    }
  }

  /// エラーメッセージを表示
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// ユーザー一覧を構築
  Widget _buildUsersList() {
    final users = _searchResults['users'] ?? [];
    if (users.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('ユーザー'),
        SizedBox(
          height: 104,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: users.length,
            itemBuilder: (context, index) => _buildUserCard(users[index]),
          ),
        ),
        const Divider(),
      ],
    );
  }

  /// ユーザーカードを構築
  Widget _buildUserCard(Map<String, dynamic> user) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: GestureDetector(
        onTap: () => _navigateToUserProfile(user),
        child: Column(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundImage: user['profile_image'] != null
                  ? NetworkImage(user['profile_image'])
                  : null,
              child: user['profile_image'] == null
                  ? const Icon(Icons.person, size: 32)
                  : null,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 64,
              child: Text(
                user['username'],
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 場所一覧を構築
  Widget _buildPlacesList() {
    final places = _searchResults['places'] ?? [];
    if (places.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('場所'),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: places.length,
          itemBuilder: (context, index) => _buildPlaceCard(places[index]),
        ),
        const Divider(),
      ],
    );
  }

  /// 場所カードを構築
  Widget _buildPlaceCard(Map<String, dynamic> place) {
    return ListTile(
      leading: const Icon(Icons.place),
      title: Text(place['name']),
      subtitle: Row(
        children: [
          const Icon(Icons.photo, size: 16),
          const SizedBox(width: 4),
          Text('${place['post_count']} 投稿'),
          const SizedBox(width: 16),
          if (place['rating'] != null) ...[
            const Icon(Icons.star, size: 16),
            const SizedBox(width: 4),
            Text(place['rating'].toString()),
          ],
        ],
      ),
      onTap: () => _navigateToPlaceDetail(place),
    );
  }

  /// セクションタイトルを構築
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 投稿一覧を構築
  Widget _buildPostsSection() {
    final posts = _searchResults['posts'] ?? [];
    if (posts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('投稿'),
        PostsGrid(
          posts: List<Map<String, dynamic>>.from(posts),
          hasNextPage: false,
          isLoading: false,
          emptyMessage: '',
          onRefresh: () => _performSearch(_searchController.text),
          onPostTap: (post) => _navigateToPostDetail(post, posts),
          gridType: 'search',
        ),
      ],
    );
  }

  /// 検索結果が空の場合のウィジェットを構築
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            '気になる場所や投稿、ユーザーを\n検索してみましょう',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  /// 検索結果なしの場合のウィジェットを構築
  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            '「${_searchController.text}」に一致する結果が\n見つかりませんでした',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  /// ユーザープロフィール画面に遷移
  Future<void> _navigateToUserProfile(Map<String, dynamic> user) async {
    final currentUserId = await _authService.getCurrentUserId();

    if (!mounted) return;

    if (user['id'].toString() == currentUserId) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ProfileScreen()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UserProfileScreen(
            userId: user['id'].toString(),
            username: user['username'],
          ),
        ),
      );
    }
  }

  /// 場所詳細画面に遷移
  void _navigateToPlaceDetail(Map<String, dynamic> place) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaceDetailScreen(
          place: {
            'id': place['id'],
            'name': place['name'],
            'latitude': place['location']?['latitude'] ?? 0.0,
            'longitude': place['location']?['longitude'] ?? 0.0,
            'rating': place['rating'],
            'favorite_count': place['favorite_count'] ?? 0,
          },
          highlightedPostId: null,
        ),
      ),
    );
  }

  /// 投稿詳細画面に遷移
  void _navigateToPostDetail(Map<String, dynamic> post, List<dynamic> posts) {
    try {
      // 投稿リストを正規化
      final normalizedPosts = PostNormalizer.normalizeList(
        posts.map((p) => Map<String, dynamic>.from(p)).toList(),
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

      // ヒーロータグを生成
      final String heroTag = HeroTagGenerator.generatePostTag(
        source: 'search',
        postId: postId,
        index: selectedIndex,
      );

      Navigator.push(
        context,
        NoAnimationMaterialPageRoute(
          builder: (context) => PostDetailScreen(
            posts: normalizedPosts,
            postId: postId,
            placeName: post['place']?['name'] ?? '検索結果',
            selectedIndex: selectedIndex,
            heroTag: heroTag,
            cachedImages: _imagePreloadFutures,
            source: 'search',
            searchQuery: _searchController.text,
          ),
        ),
      );
    } catch (e) {
      _showError('投稿の表示中にエラーが発生しました: $e');
      print('Error in _navigateToPostDetail: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseLayout(
      child: Scaffold(
        appBar: AppBar(
          title: Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: '検索',
                prefixIcon: Icon(Icons.search),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 4),
              ),
              onChanged: (value) {
                _debounceTimer?.cancel();
                _debounceTimer = Timer(
                  const Duration(milliseconds: 500),
                  () => _performSearch(value),
                );
              },
            ),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () => _performSearch(_searchController.text),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      if (_searchResults.isEmpty &&
                          _searchController.text.isEmpty)
                        _buildEmptyState()
                      else if (_searchResults.isEmpty &&
                          _searchController.text.isNotEmpty)
                        _buildNoResults()
                      else ...[
                        _buildUsersList(),
                        _buildPlacesList(),
                        _buildPostsSection(),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

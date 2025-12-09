/// TerraPicアプリの改善された検索画面
///
/// 新機能:
/// - 検索サジェスト（オートコンプリート）
/// - 検索履歴の保存と表示
/// - タブフィルター（すべて/場所/投稿/ユーザー）
/// - キーボード最適化（検索ボタン、Enter押下対応）
/// - 改善されたUX
///
import 'package:flutter/foundation.dart';
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
import '../services/search_history_service.dart';

enum SearchTab { all, places, posts, users }

class EnhancedSearchScreen extends StatefulWidget {
  const EnhancedSearchScreen({Key? key}) : super(key: key);

  @override
  _EnhancedSearchScreenState createState() => _EnhancedSearchScreenState();
}

class _EnhancedSearchScreenState extends State<EnhancedSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final AuthService _authService = AuthService();

  Map<String, dynamic> _searchResults = {};
  List<Map<String, dynamic>> _suggestions = [];
  List<String> _searchHistory = [];

  bool _isLoading = false;
  bool _showSuggestions = false;
  SearchTab _currentTab = SearchTab.all;

  Timer? _debounceTimer;
  Timer? _suggestionTimer;

  // 画像のプリロード用のMap
  final Map<String, Future<void>> _imagePreloadFutures = {};

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
    _searchFocusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    _suggestionTimer?.cancel();
    super.dispose();
  }

  /// フォーカス変更時の処理
  void _onFocusChange() {
    if (_searchFocusNode.hasFocus && _searchController.text.isEmpty) {
      setState(() => _showSuggestions = true);
    }
  }

  /// 検索履歴を読み込む
  Future<void> _loadSearchHistory() async {
    final history = await SearchHistoryService.getHistory();
    if (mounted) {
      setState(() => _searchHistory = history);
    }
  }

  /// サジェストを取得
  Future<void> _fetchSuggestions(String query) async {
    if (query.length < 2) {
      setState(() {
        _suggestions = [];
        _showSuggestions = _searchController.text.isEmpty;
      });
      return;
    }

    try {
      final url = Uri.parse('${AppConfig.backendUrl}/api/search/suggestions/')
          .replace(queryParameters: {'q': query});

      final response = await http.get(url);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _suggestions = List<Map<String, dynamic>>.from(data['suggestions'] ?? []);
          _showSuggestions = true;
        });
      }
    } catch (e) {
      // サジェスト取得失敗は無視（検索機能には影響なし）
      if (kDebugMode) {
        debugPrint('サジェスト取得エラー: $e');
      }
    }
  }

  /// 検索を実行
  Future<void> _performSearch(String query, {bool saveToHistory = true}) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = {};
        _showSuggestions = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _showSuggestions = false;
    });

    // 検索履歴に保存
    if (saveToHistory) {
      await SearchHistoryService.addToHistory(query);
      await _loadSearchHistory();
    }

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

  /// 検索バーを構築
  Widget _buildSearchBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(24),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: '場所、投稿、ユーザーを検索',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchResults = {};
                      _showSuggestions = true;
                      _currentTab = SearchTab.all;
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onChanged: (value) {
          setState(() {});

          // サジェスト取得
          _suggestionTimer?.cancel();
          _suggestionTimer = Timer(
            const Duration(milliseconds: 300),
            () => _fetchSuggestions(value),
          );

          // 検索実行
          _debounceTimer?.cancel();
          _debounceTimer = Timer(
            const Duration(milliseconds: 500),
            () => _performSearch(value),
          );
        },
        onSubmitted: (value) {
          _performSearch(value);
        },
      ),
    );
  }

  /// サジェストと履歴を表示
  Widget _buildSuggestionsAndHistory() {
    if (!_showSuggestions) return const SizedBox.shrink();

    return Container(
      color: Colors.white,
      child: ListView(
        shrinkWrap: true,
        children: [
          // サジェスト
          if (_suggestions.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '候補',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            ..._suggestions.map((suggestion) => ListTile(
                  leading: Icon(
                    suggestion['type'] == 'place'
                        ? Icons.place
                        : Icons.person,
                    color: Colors.grey[600],
                  ),
                  title: Text(suggestion['text']),
                  onTap: () {
                    _searchController.text = suggestion['text'];
                    _performSearch(suggestion['text']);
                  },
                )),
          ],

          // 検索履歴
          if (_searchHistory.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '最近の検索',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await SearchHistoryService.clearHistory();
                      await _loadSearchHistory();
                    },
                    child: const Text('クリア'),
                  ),
                ],
              ),
            ),
            ..._searchHistory.map((query) => ListTile(
                  leading: Icon(Icons.history, color: Colors.grey[600]),
                  title: Text(query),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () async {
                      await SearchHistoryService.removeFromHistory(query);
                      await _loadSearchHistory();
                    },
                  ),
                  onTap: () {
                    _searchController.text = query;
                    _performSearch(query, saveToHistory: false);
                  },
                )),
          ],

          // 空の状態
          if (_suggestions.isEmpty && _searchHistory.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.search, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    '場所、投稿、ユーザーを検索してみましょう',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// タブバーを構築
  Widget _buildTabBar() {
    if (_searchResults.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        children: [
          _buildTab(SearchTab.all, 'すべて'),
          _buildTab(SearchTab.places, '場所'),
          _buildTab(SearchTab.posts, '投稿'),
          _buildTab(SearchTab.users, 'ユーザー'),
        ],
      ),
    );
  }

  /// 個別のタブを構築
  Widget _buildTab(SearchTab tab, String label) {
    final isSelected = _currentTab == tab;

    // 各タブの件数を取得
    int count = 0;
    switch (tab) {
      case SearchTab.all:
        count = (_searchResults['users']?.length ?? 0) +
                (_searchResults['places']?.length ?? 0) +
                (_searchResults['posts']?.length ?? 0);
        break;
      case SearchTab.places:
        count = _searchResults['places']?.length ?? 0;
        break;
      case SearchTab.posts:
        count = _searchResults['posts']?.length ?? 0;
        break;
      case SearchTab.users:
        count = _searchResults['users']?.length ?? 0;
        break;
    }

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentTab = tab),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Center(
            child: Text(
              '$label${count > 0 ? ' ($count)' : ''}',
              style: TextStyle(
                color: isSelected ? Theme.of(context).primaryColor : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 検索結果を表示
  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) return const SizedBox.shrink();

    switch (_currentTab) {
      case SearchTab.all:
        return _buildAllResults();
      case SearchTab.places:
        return _buildPlacesList();
      case SearchTab.posts:
        return _buildPostsSection();
      case SearchTab.users:
        return _buildUsersList(fullList: true);
    }
  }

  /// すべての結果を表示
  Widget _buildAllResults() {
    final hasUsers = (_searchResults['users']?.length ?? 0) > 0;
    final hasPlaces = (_searchResults['places']?.length ?? 0) > 0;
    final hasPosts = (_searchResults['posts']?.length ?? 0) > 0;

    if (!hasUsers && !hasPlaces && !hasPosts) {
      return _buildNoResults();
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          if (hasUsers) _buildUsersList(fullList: false),
          if (hasPlaces) _buildPlacesList(),
          if (hasPosts) _buildPostsSection(),
        ],
      ),
    );
  }

  /// ユーザー一覧を構築
  Widget _buildUsersList({required bool fullList}) {
    final users = _searchResults['users'] ?? [];
    if (users.isEmpty) return const SizedBox.shrink();

    final displayUsers = fullList ? users : users.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!fullList) _buildSectionTitle('ユーザー'),
        if (fullList)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayUsers.length,
            itemBuilder: (context, index) => _buildUserListTile(displayUsers[index]),
          )
        else
          SizedBox(
            height: 104,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: displayUsers.length,
              itemBuilder: (context, index) => _buildUserCard(displayUsers[index]),
            ),
          ),
        if (!fullList && users.length > 5)
          TextButton(
            onPressed: () => setState(() => _currentTab = SearchTab.users),
            child: Text('すべてのユーザーを見る (${users.length})'),
          ),
        if (!fullList) const Divider(),
      ],
    );
  }

  /// ユーザーカードを構築（横スクロール用）
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

  /// ユーザーリストタイル を構築（リスト表示用）
  Widget _buildUserListTile(Map<String, dynamic> user) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: user['profile_image'] != null
            ? NetworkImage(user['profile_image'])
            : null,
        child: user['profile_image'] == null
            ? const Icon(Icons.person)
            : null,
      ),
      title: Text(user['username']),
      subtitle: user['name'] != null ? Text(user['name']) : null,
      onTap: () => _navigateToUserProfile(user),
    );
  }

  /// 場所一覧を構築
  Widget _buildPlacesList() {
    final places = _searchResults['places'] ?? [];
    if (places.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_currentTab == SearchTab.all) _buildSectionTitle('場所'),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: places.length,
          itemBuilder: (context, index) => _buildPlaceCard(places[index]),
        ),
        if (_currentTab == SearchTab.all) const Divider(),
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
        if (_currentTab == SearchTab.all) _buildSectionTitle('投稿'),
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

  /// 検索結果なしの場合のウィジェットを構築
  Widget _buildNoResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
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
      if (kDebugMode) {
        debugPrint('Error in _navigateToPostDetail: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseLayout(
      child: Scaffold(
        appBar: AppBar(
          title: _buildSearchBar(),
          automaticallyImplyLeading: false,
        ),
        body: Column(
          children: [
            _buildTabBar(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _showSuggestions
                      ? _buildSuggestionsAndHistory()
                      : RefreshIndicator(
                          onRefresh: () => _performSearch(_searchController.text),
                          child: _searchResults.isEmpty
                              ? const Center(child: Text('検索してください'))
                              : _buildSearchResults(),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

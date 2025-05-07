/// TerraPicアプリのランキング画面
///
/// お気に入りの多い場所と人気の投稿を表示する。
/// 週間、月間、総合の期間切り替えが可能。
///
/// 主な機能:
/// - 人気の場所ランキング
/// - 人気の投稿ランキング
/// - 期間による表示切り替え
/// - ランキング詳細の表示
///
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../shared/widgets/base_layout.dart';
import 'dart:convert';
import '../../../core/config/app_config.dart';
import '../../places/screens/place_detail_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../profile/screens/profile_user_screen.dart';
import '../../../features/auth/services/auth_service.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({Key? key}) : super(key: key);

  @override
  _RankingScreenState createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _popularPlaces = [];
  List<dynamic> _popularPosts = [];
  String _selectedPeriod = 'all';
  bool _isLoading = true;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchRankingData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// ランキングデータを取得
  Future<void> _fetchRankingData() async {
    setState(() => _isLoading = true);

    try {
      // 場所と投稿のランキングを並列で取得
      final results = await Future.wait([
        http.get(Uri.parse(
            '${AppConfig.backendUrl}/api/ranking/places?period=$_selectedPeriod&limit=10')),
        http.get(Uri.parse(
            '${AppConfig.backendUrl}/api/ranking/posts?period=$_selectedPeriod&limit=10')),
      ]);

      if (!mounted) return;

      if (results[0].statusCode == 200 && results[1].statusCode == 200) {
        setState(() {
          _popularPlaces = json.decode(utf8.decode(results[0].bodyBytes));
          _popularPosts = json.decode(utf8.decode(results[1].bodyBytes));
          _isLoading = false;
        });
      } else {
        throw Exception('ランキングの取得に失敗しました');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('データの取得に失敗しました');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// 期間選択セグメントを構築
  Widget _buildPeriodSelector() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: SegmentedButton<String>(
        segments: const [
          ButtonSegment(
            value: 'all',
            label: Text('総合'),
            icon: Icon(Icons.all_inclusive),
          ),
          ButtonSegment(
            value: 'monthly',
            label: Text('月間'),
            icon: Icon(Icons.calendar_month),
          ),
          ButtonSegment(
            value: 'weekly',
            label: Text('週間'),
            icon: Icon(Icons.calendar_view_week),
          ),
        ],
        selected: {_selectedPeriod},
        onSelectionChanged: (Set<String> selection) {
          setState(() => _selectedPeriod = selection.first);
          _fetchRankingData();
        },
      ),
    );
  }

  /// ランキングバッジを構築
  Widget _buildRankBadge(int index) {
    final colors = [
      const Color(0xFFFFD700), // Gold
      const Color(0xFFC0C0C0), // Silver
      const Color(0xFFCD7F32), // Bronze
    ];

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: index < 3 ? colors[index] : Colors.grey[300],
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Text(
          '${index + 1}',
          style: TextStyle(
            color: index < 3 ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseLayout(
      child: Scaffold(
        appBar: AppBar(
          title: const Row(
            children: [
              Icon(Icons.emoji_events),
              SizedBox(width: 8),
              Text('ランキング'),
            ],
          ),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.place), text: '人気スポット'),
              Tab(icon: Icon(Icons.photo), text: '人気の投稿'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  // 場所ランキング
                  Column(
                    children: [
                      _buildPeriodSelector(),
                      Expanded(
                        child: _popularPlaces.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _popularPlaces.length,
                                itemBuilder: (context, index) {
                                  final place = _popularPlaces[index];
                                  return Card(
                                    elevation: index < 3 ? 4 : 2,
                                    margin: const EdgeInsets.only(bottom: 16),
                                    child: ListTile(
                                      leading: _buildRankBadge(index),
                                      title: Text(
                                        place['name'],
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('投稿数: ${place['post_count']}件'),
                                          if (place['rating'] != null)
                                            Row(
                                              children: [
                                                const Icon(Icons.star,
                                                    size: 16,
                                                    color: Colors.amber),
                                                Text(
                                                    ' ${place['rating'].toStringAsFixed(1)}'),
                                              ],
                                            ),
                                        ],
                                      ),
                                      trailing: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.bookmark,
                                              color: Colors.blue),
                                          Text('${place['favorite_count']}'),
                                        ],
                                      ),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                PlaceDetailScreen(
                                              place: place,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),

                  // 投稿ランキング
                  Column(
                    children: [
                      _buildPeriodSelector(),
                      Expanded(
                        child: _popularPosts.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _popularPosts.length,
                                itemBuilder: (context, index) {
                                  final post = _popularPosts[index];
                                  return Card(
                                    elevation: index < 3 ? 4 : 2,
                                    margin: const EdgeInsets.only(bottom: 16),
                                    child: Column(
                                      children: [
                                        Stack(
                                          children: [
                                            AspectRatio(
                                              aspectRatio: 16 / 9,
                                              child: Image.network(
                                                post['photo_image'],
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                            Positioned(
                                              top: 8,
                                              left: 8,
                                              child: _buildRankBadge(index),
                                            ),
                                          ],
                                        ),
                                        ListTile(
                                          title: Text(post['place']['name']),
                                          subtitle: GestureDetector(
                                            onTap: () async {
                                              final currentUserId =
                                                  await _authService
                                                      .getCurrentUserId();
                                              if (post['user']['id']
                                                      .toString() ==
                                                  currentUserId) {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        const ProfileScreen(),
                                                  ),
                                                );
                                              } else {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        UserProfileScreen(
                                                      userId: post['user']['id']
                                                          .toString(),
                                                      username: post['user']
                                                          ['username'],
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                            child: Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 12,
                                                  backgroundImage: post['user'][
                                                              'profile_image'] !=
                                                          null
                                                      ? NetworkImage(
                                                          post['user']
                                                              ['profile_image'])
                                                      : null,
                                                  child: post['user'][
                                                              'profile_image'] ==
                                                          null
                                                      ? const Icon(Icons.person,
                                                          size: 16)
                                                      : null,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(post['user']['username']),
                                              ],
                                            ),
                                          ),
                                          trailing: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(Icons.favorite,
                                                  color: Colors.red),
                                              Text('${post['like_count']}'),
                                            ],
                                          ),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    PlaceDetailScreen(
                                                  place: post['place'],
                                                  highlightedPostId: post['id'],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            _selectedPeriod == 'weekly'
                ? '今週のランキングはまだありません'
                : _selectedPeriod == 'monthly'
                    ? '今月のランキングはまだありません'
                    : 'ランキングはまだありません',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

/// TerraPicアプリのフォロー/フォロワー一覧画面
///
/// ユーザーのフォロー/フォロワーリストを表示し、
/// フォロー/アンフォロー操作を提供する。
///
/// 主な機能:
/// - フォロー/フォロワーの一覧表示
/// - フォロー/アンフォロー操作
/// - ユーザープロフィールへの遷移
/// - ページネーション
///
import 'package:flutter/material.dart';
import '../../../shared/widgets/base_layout.dart';
import '../../../features/auth/services/auth_service.dart';
import 'dart:convert';
import 'profile_screen.dart';
import 'profile_user_screen.dart';

class FollowListScreen extends StatefulWidget {
  final String userId;
  final String title;
  final bool isFollowers;

  const FollowListScreen({
    Key? key,
    required this.userId,
    required this.title,
    required this.isFollowers,
  }) : super(key: key);

  @override
  _FollowListScreenState createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  final AuthService _authService = AuthService();
  final ScrollController _scrollController = ScrollController();
  String? currentUserId;

  List<Map<String, dynamic>> users = [];
  bool isLoading = false;
  bool isLoadingMore = false;
  bool hasNextPage = true;
  int currentPage = 1;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _getCurrentUserId();
    _fetchUsers();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _fetchMoreUsers();
    }
  }

  Future<void> _getCurrentUserId() async {
    try {
      final id = await _authService.getCurrentUserId();
      if (mounted) {
        setState(() => currentUserId = id);
      }
    } catch (e) {
      print('Error getting current user ID: $e');
    }
  }

  Future<void> _fetchUsers() async {
    if (isLoading || widget.userId.isEmpty) return;

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final endpoint = widget.isFollowers
          ? '/api/users/${widget.userId}/followers/'
          : '/api/users/${widget.userId}/following/';

      final response =
          await _authService.authenticatedRequest('$endpoint?page=1');

      if (response.statusCode == 200) {
        final jsonData = json.decode(utf8.decode(response.bodyBytes));

        setState(() {
          users = List<Map<String, dynamic>>.from(jsonData['users']);
          hasNextPage = jsonData['has_next'];
          currentPage = 1;
        });
      } else {
        throw Exception('Failed to load users: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => errorMessage = 'ユーザー情報の読み込みに失敗しました。');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchMoreUsers() async {
    if (isLoadingMore || !hasNextPage) return;

    setState(() => isLoadingMore = true);

    try {
      final endpoint = widget.isFollowers
          ? '/api/users/${widget.userId}/followers/'
          : '/api/users/${widget.userId}/following/';

      final response = await _authService
          .authenticatedRequest('$endpoint?page=${currentPage + 1}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(utf8.decode(response.bodyBytes));
        final newUsers = List<Map<String, dynamic>>.from(jsonData['users']);

        setState(() {
          users.addAll(newUsers);
          hasNextPage = jsonData['has_next'];
          currentPage++;
        });
      } else {
        throw Exception('Failed to load more users');
      }
    } catch (e) {
      setState(() => errorMessage = '追加のユーザー情報の読み込みに失敗しました。');
    } finally {
      setState(() => isLoadingMore = false);
    }
  }

  Future<void> _toggleFollow(int userId, bool currentlyFollowing) async {
    try {
      final response = await _authService.authenticatedRequest(
        '/api/users/$userId/follow',
        method: currentlyFollowing ? 'DELETE' : 'POST',
      );

      if (response.statusCode == 200) {
        setState(() {
          final userIndex = users.indexWhere((user) => user['id'] == userId);
          if (userIndex != -1) {
            users[userIndex]['is_following'] = !currentlyFollowing;
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(currentlyFollowing ? 'フォロー解除に失敗しました' : 'フォローに失敗しました'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userId.isEmpty) {
      return BaseLayout(
        child: Scaffold(
          appBar: AppBar(title: Text(widget.title)),
          body: const Center(child: Text('ユーザー情報が取得できません。')),
        ),
      );
    }

    return BaseLayout(
      child: Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage.isNotEmpty
                ? Center(child: Text(errorMessage))
                : RefreshIndicator(
                    onRefresh: _fetchUsers,
                    child: users.isEmpty
                        ? const Center(child: Text('ユーザーが見つかりません'))
                        : ListView.builder(
                            controller: _scrollController,
                            itemCount: users.length + (isLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == users.length) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }

                              final user = users[index];
                              final isFollowing = user['is_following'] ?? false;
                              final isCurrentUser =
                                  user['id'].toString() == currentUserId;

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: user['profile_image'] != null
                                      ? NetworkImage(user['profile_image'])
                                      : null,
                                  child: user['profile_image'] == null
                                      ? const Icon(Icons.person)
                                      : null,
                                ),
                                title: Text('@${user['username']}'),
                                subtitle: Text(user['name'] ?? ''),
                                trailing: !isCurrentUser
                                    ? TextButton(
                                        style: TextButton.styleFrom(
                                          backgroundColor: isFollowing
                                              ? Colors.grey[200]
                                              : Colors.blue,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                        ),
                                        onPressed: () => _toggleFollow(
                                          user['id'],
                                          isFollowing,
                                        ),
                                        child: Text(
                                          isFollowing ? 'フォロー中' : 'フォローする',
                                          style: TextStyle(
                                            color: isFollowing
                                                ? Colors.black
                                                : Colors.white,
                                          ),
                                        ),
                                      )
                                    : null,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => isCurrentUser
                                          ? const ProfileScreen()
                                          : UserProfileScreen(
                                              userId: user['id'].toString(),
                                              username: user['username'],
                                            ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),
      ),
    );
  }
}

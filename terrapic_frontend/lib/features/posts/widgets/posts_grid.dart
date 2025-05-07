/// TerraPicアプリの投稿グリッド
///
/// 投稿写真をグリッド形式で表示するウィジェット。
/// プロフィール画面や場所詳細画面などで使用される。
///
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:terrapic_frontend/core/config/app_config.dart';
import 'package:terrapic_frontend/shared/utils/hero_tag_generator.dart';

class PostsGrid extends StatefulWidget {
  final List<Map<String, dynamic>> posts;
  final bool hasNextPage;
  final bool isLoading;
  final String emptyMessage;
  final Function() onRefresh;
  final Function()? onLoadMore;
  final Function(Map<String, dynamic>) onPostTap;
  final String gridType;

  const PostsGrid({
    Key? key,
    required this.posts,
    required this.hasNextPage,
    required this.isLoading,
    required this.emptyMessage,
    required this.onRefresh,
    required this.onPostTap,
    required this.gridType,
    this.onLoadMore,
  }) : super(key: key);

  @override
  State<PostsGrid> createState() => _PostsGridState();
}

class _PostsGridState extends State<PostsGrid> {
  final Map<String, Future<void>> _imagePreloadFutures = {};

  @override
  void initState() {
    super.initState();
    _preloadImages(widget.posts);
  }

  @override
  void didUpdateWidget(PostsGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.posts.length > oldWidget.posts.length) {
      final newPosts = widget.posts.sublist(oldWidget.posts.length);
      _preloadImages(newPosts);
    }
  }

  String _getFullImageUrl(String? partialUrl) {
    if (partialUrl == null || partialUrl.isEmpty) return '';
    if (partialUrl.startsWith('http')) {
      return partialUrl;
    }
    return '${AppConfig.backendUrl}${partialUrl.startsWith('/') ? '' : '/'}$partialUrl';
  }

  Future<void> _preloadImages(List<Map<String, dynamic>> items) async {
    for (var item in items) {
      String? imageUrl = item['url'] ?? item['photo_image'];
      if (imageUrl != null && imageUrl.isNotEmpty) {
        try {
          String fullUrl = _getFullImageUrl(imageUrl);
          if (!_imagePreloadFutures.containsKey(fullUrl)) {
            _imagePreloadFutures[fullUrl] = DefaultCacheManager()
                .downloadFile(fullUrl)
                .onError((error, stackTrace) {
              print('Failed to preload image $fullUrl: $error');
              throw error!; // エラーを再スロー
            });
          }
        } catch (e) {
          print('Error processing image URL: $e');
        }
      }
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Icon(
          Icons.image_not_supported,
          color: Colors.grey[400],
          size: 24,
        ),
      ),
    );
  }

  Widget _buildPostItem(Map<String, dynamic> post, int index) {
    String? imageUrl = post['url'] ?? post['photo_image'];
    if (imageUrl == null || imageUrl.isEmpty) return _buildPlaceholder();

    final fullImageUrl = _getFullImageUrl(imageUrl);
    final postId =
        post['id'] is int ? post['id'] : int.parse(post['id'].toString());

    // データの実際のインデックスを保存
    final dataIndex = widget.posts.indexWhere((p) =>
        (p['id'] is int ? p['id'] : int.parse(p['id'].toString())) == postId);

    // Heroタグを生成（データインデックスを使用）
    final heroTag = HeroTagGenerator.generatePostTag(
      source: widget.gridType,
      postId: postId,
      index: dataIndex, // グリッドインデックスではなくデータインデックスを使用
    );

    print('Building PostItem:');
    print('Post ID: ${post['id']}');
    print('Grid Index: $index');
    print('URL: $fullImageUrl');

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: GestureDetector(
        onTap: () {
          final postData = {
            ...post,
            'url': fullImageUrl,
            'photo_image': fullImageUrl,
            '_grid_index': index,
            'id': postId,
            '_hero_tag': heroTag,
            '_data_index': index,
            '_original_data': post, // 元のデータも保持
          };
          print('Tapped post data: $postData');
          widget.onPostTap(postData);
        },
        child: Hero(
          tag: heroTag,
          child: Image.network(
            fullImageUrl,
            fit: BoxFit.cover,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              return frame == null ? _buildPlaceholder() : child;
            },
            errorBuilder: (context, error, stackTrace) {
              print('Image load error for $fullImageUrl: $error');
              return _buildPlaceholder();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: MediaQuery.of(context).size.height - 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              widget.emptyMessage,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.posts.isEmpty && !widget.isLoading) {
      return _buildEmptyState();
    }

    // originalPostsとしてコピーを保持
    final originalPosts = List<Map<String, dynamic>>.from(widget.posts);

    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: MasonryGridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          padding: const EdgeInsets.all(8),
          itemCount: originalPosts.length + (widget.hasNextPage ? 1 : 0),
          itemBuilder: (context, index) {
            if (index < originalPosts.length) {
              // 元のデータの順序を保持したまま表示
              return _buildPostItem(originalPosts[index], index);
            } else if (widget.hasNextPage) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

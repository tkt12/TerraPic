from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework import status
from django.core.cache import cache
from ..serializers import SearchSerializer
from ..services import PlaceService, PostService, ProfileService
from ..utils import format_api_error
import logging

logger = logging.getLogger(__name__)

@api_view(['GET'])
@permission_classes([AllowAny])
def search(request):
    """
    統合検索API
    
    ユーザー、投稿、場所を横断的に検索する
    
    Parameters:
        q: 検索クエリ
    
    Returns:
        users: ユーザー検索結果
        posts: 投稿検索結果
        places: 場所検索結果
    """
    try:
        # 検索クエリの取得と検証
        query = request.GET.get('q', '').strip()
        logger.debug(f"検索クエリ: {query}")  # クエリのログ
        
        if not query:
            return Response({
                'users': [],
                'posts': [],
                'places': []
            })

        # キャッシュのチェック
        cache_key = f'search_{query}'
        cached_results = cache.get(cache_key)
        
        if cached_results:
            logger.debug("キャッシュからの結果を返します")
            return Response(cached_results)

        try:
            # ユーザー検索
            users = ProfileService.search_users(query=query, limit=10)
            logger.debug(f"ユーザー検索結果: {len(users)}件")
            
            # 投稿検索
            posts = PostService.search_posts(query=query, limit=30)
            logger.debug(f"投稿検索結果: {len(posts)}件")
            
            # 場所検索
            places = PlaceService.search_places(query=query, limit=15)
            logger.debug(f"場所検索結果: {len(places)}件")

            # 検索結果の整形
            response_data = {
                'users': [
                    SearchSerializer.format_user(user, request)
                    for user in users
                ],
                'posts': [
                    SearchSerializer.format_post(post, request)
                    for post in posts
                ],
                'places': [
                    SearchSerializer.format_place(
                        place, 
                        request, 
                        top_post=getattr(place, 'top_posts', [])[0] 
                            if hasattr(place, 'top_posts') and place.top_posts 
                            else None
                    )
                    for place in places
                ]
            }
            
            logger.debug(f"フォーマット後の結果: users={len(response_data['users'])}, "
                        f"posts={len(response_data['posts'])}, "
                        f"places={len(response_data['places'])}")

            # 結果をキャッシュ
            cache.set(cache_key, response_data, 300)
            return Response(response_data)

        except Exception as search_error:
            logger.error(f"検索処理中にエラー: {search_error}", exc_info=True)
            raise

    except Exception as e:
        logger.error(f"検索API実行中にエラー: {str(e)}", exc_info=True)
        return Response(
            format_api_error('検索中にエラーが発生しました。'),
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )
@api_view(['GET'])
@permission_classes([AllowAny])
def search_suggestions(request):
    """
    検索サジェストAPI
    
    入力中の検索クエリに対してサジェストを提供
    
    Parameters:
        q: 入力中の検索クエリ
        
    Returns:
        suggestions: サジェスト候補のリスト
    """
    try:
        query = request.GET.get('q', '').strip()
        
        if not query or len(query) < 2:
            return Response({'suggestions': []})

        # キャッシュキーの生成
        cache_key = f'suggest_{query}'
        cached_suggestions = cache.get(cache_key)
        
        if cached_suggestions:
            return Response({'suggestions': cached_suggestions})

        # 各サービスを使用してサジェストを取得
        place_suggestions = PlaceService.get_search_suggestions(
            query=query,
            limit=5
        )
        
        user_suggestions = ProfileService.get_search_suggestions(
            query=query,
            limit=3
        )

        # サジェスト結果の整形
        suggestions = [
            {'type': 'place', 'text': place.name, 'id': place.id}
            for place in place_suggestions
        ] + [
            {'type': 'user', 'text': user.username, 'id': user.id}
            for user in user_suggestions
        ]

        # 結果をキャッシュ（3分間）
        cache.set(cache_key, suggestions, 180)

        return Response({'suggestions': suggestions})

    except Exception as e:
        logger.error(f"サジェスト取得中にエラー: {str(e)}")
        return Response(
            format_api_error('サジェストの取得中にエラーが発生しました。'),
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )
from rest_framework import status
from rest_framework.decorators import (
    api_view, permission_classes, parser_classes
)
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from django.core.paginator import Paginator
from django.db.models import Count, Sum
from ..models import Users, Follows, Posts, Places, Favorites
from ..serializers import ProfileSerializer, PostSerializer
from ..services import ProfileService, PostService
from ..utils import format_api_error
import logging


logger = logging.getLogger(__name__)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def profile(request):
    """
    ログインユーザーのプロフィール情報を取得するAPI
    """
    try:
        # プロフィール情報と統計データの取得
        profile_data = ProfileService.get_profile_details(
            user_id=request.user.id
        )

        # ページネーション情報
        page = int(request.GET.get('page', 1))
        posts_per_page = 12

        # 投稿データの取得
        posts, total_posts = PostService.get_user_posts(
            user_id=request.user.id,
            page=page,
            per_page=posts_per_page
        )

        posts_serializer = PostSerializer(
            posts,
            many=True,
            context={'request': request}
        )

        response_data = {
            'profile': ProfileSerializer(profile_data['user']).data,
            'posts': posts_serializer.data,
            'has_next': (page * posts_per_page) < total_posts,
            'total_posts': total_posts,
            'statistics': profile_data['statistics']
        }

        return Response(response_data)

    except Exception as e:
        logger.error(f"プロフィール取得中にエラー: {str(e)}")
        return Response(
            format_api_error('プロフィールの取得中にエラーが発生しました。'),
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

@api_view(['GET', 'PUT'])
@permission_classes([IsAuthenticated])
@parser_classes([MultiPartParser, FormParser, JSONParser])
def profile_edit(request):
    """
    プロフィール情報を編集するAPI
    
    GET: 現在のプロフィール情報を取得
    PUT: プロフィール情報を更新
    """
    try:
        if request.method == 'GET':
            serializer = ProfileSerializer(request.user)
            return Response(serializer.data)

        elif request.method == 'PUT':
            # ProfileServiceを使用してプロフィールを更新
            updated_user = ProfileService.update_profile(
                user=request.user,
                profile_data=request.data,
                profile_image=request.FILES.get('profile_image')
            )
            
            serializer = ProfileSerializer(updated_user)
            return Response(serializer.data)

    except ValueError as e:
        return Response(
            format_api_error(str(e)),
            status=status.HTTP_400_BAD_REQUEST
        )
    except Exception as e:
        logger.error(f"プロフィール編集中にエラー: {str(e)}")
        return Response(
            format_api_error('プロフィールの編集中にエラーが発生しました。'),
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def user_profile(request, user_id):
    """
    指定したユーザーのプロフィール情報を取得するAPI
    """
    try:
        # プロフィール情報と統計データの取得
        profile_data = ProfileService.get_profile_details(user_id)

        # ページネーション情報
        page = int(request.GET.get('page', 1))
        posts_per_page = 12

        # 投稿データの取得
        posts, total_posts = PostService.get_user_posts(
            user_id=user_id,
            page=page,
            per_page=posts_per_page
        )

        # フォロー状態の確認
        is_following = Follows.objects.filter(
            follower=request.user,
            followed_id=user_id
        ).exists()

        response_data = {
            'profile': ProfileSerializer(profile_data['user']).data,
            'posts': PostSerializer(posts, many=True, context={'request': request}).data,
            'has_next': (page * posts_per_page) < total_posts,
            'total_posts': total_posts,
            'is_following': is_following,
            'statistics': profile_data['statistics']
        }

        return Response(response_data)

    except Users.DoesNotExist:
        return Response(
            format_api_error('ユーザーが見つかりません'),
            status=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"ユーザープロフィール取得中にエラー: {str(e)}")
        return Response(
            format_api_error('プロフィールの取得中にエラーが発生しました。'),
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

@api_view(['POST', 'DELETE'])
@permission_classes([IsAuthenticated])
def follow_toggle(request, user_id):
    """
    ユーザーのフォロー・アンフォローを切り替えるAPI
    """
    try:
        # ProfileServiceを使用してフォロー状態を切り替え
        is_following, follower_count = ProfileService.toggle_follow(
            follower_id=request.user.id,
            followed_id=user_id
        )
        
        status_msg = 'followed' if is_following else 'unfollowed'
        
        return Response({
            'status': status_msg,
            'follower_count': follower_count
        })

    except ValueError as e:
        return Response(
            format_api_error(str(e)),
            status=status.HTTP_400_BAD_REQUEST
        )
    except Users.DoesNotExist:
        return Response(
            format_api_error('ユーザーが見つかりません'),
            status=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"フォロー処理中にエラー: {str(e)}")
        return Response(
            format_api_error('フォロー処理中にエラーが発生しました。'),
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_followers(request, user_id):
    """
    ユーザーのフォロワー一覧を取得するAPI
    """
    try:
        page = int(request.GET.get('page', 1))
        per_page = 20

        # ProfileServiceを使用してフォロワー一覧を取得
        followers, total_count = ProfileService.get_followers(
            user_id=user_id,
            page=page,
            per_page=per_page
        )
        
        followers_data = [{
            'id': follow.follower.id,
            'username': follow.follower.username,
            'name': follow.follower.name,
            'profile_image': request.build_absolute_uri(
                follow.follower.profile_image.url
            ) if follow.follower.profile_image else None,
            'is_following': Follows.objects.filter(
                follower=request.user,
                followed=follow.follower
            ).exists()
        } for follow in followers]
        
        return Response({
            'users': followers_data,
            'has_next': (page * per_page) < total_count,
            'total_count': total_count
        })
        
    except Exception as e:
        logger.error(f"フォロワー一覧取得中にエラー: {str(e)}")
        return Response(
            format_api_error('フォロワー一覧の取得中にエラーが発生しました。'),
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_following(request, user_id):
    """
    ユーザーのフォロー中ユーザー一覧を取得するAPI
    """
    try:
        page = int(request.GET.get('page', 1))
        per_page = 20

        # ProfileServiceを使用してフォロー中ユーザー一覧を取得
        following, total_count = ProfileService.get_following(
            user_id=user_id,
            page=page,
            per_page=per_page
        )
        
        following_data = [{
            'id': follow.followed.id,
            'username': follow.followed.username,
            'name': follow.followed.name,
            'profile_image': request.build_absolute_uri(
                follow.followed.profile_image.url
            ) if follow.followed.profile_image else None,
            'is_following': Follows.objects.filter(
                follower=request.user,
                followed=follow.followed
            ).exists()
        } for follow in following]
        
        return Response({
            'users': following_data,
            'has_next': (page * per_page) < total_count,
            'total_count': total_count
        })
        
    except Exception as e:
        logger.error(f"フォロー中ユーザー一覧取得中にエラー: {str(e)}")
        return Response(
            format_api_error('フォロー中ユーザー一覧の取得中にエラーが発生しました。'),
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def profile_likes(request):
    """ユーザーがいいねした投稿を取得するエンドポイント"""
    try:
        user = request.user
        page = int(request.GET.get('page', 1))
        posts_per_page = 12
        
        liked_posts = Posts.objects.filter(
            likes__user=user
        ).order_by('-likes__created_at')
        
        paginator = Paginator(liked_posts, posts_per_page)
        page_obj = paginator.get_page(page)
        
        serializer = PostSerializer(page_obj, many=True, context={'request': request})
        
        return Response({
            'posts': serializer.data,
            'has_next': page_obj.has_next(),
            'total_posts': liked_posts.count(),
        })
    except Exception as e:
        logger.error(f"いいね投稿取得中にエラー: {str(e)}")
        return Response(
            {'error': 'いいね投稿の取得中にエラーが発生しました。'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def profile_favorites(request):
    """ユーザーがお気に入りした場所を取得するエンドポイント"""
    try:
        user = request.user
        page = int(request.GET.get('page', 1))
        places_per_page = 10
        
        favorite_places = Places.objects.filter(
            favorites__user=user
        ).annotate(
            post_count=Count('posts'),
            total_likes=Sum('posts__like_count')  # 総いいね数を追加
        ).order_by('-favorites__created_at')
        
        paginator = Paginator(favorite_places, places_per_page)
        page_obj = paginator.get_page(page)
        
        places_data = []
        for place in page_obj:
            # トップ投稿を取得
            top_post = Posts.objects.filter(
                place=place
            ).order_by('-like_count', '-created_at').first()
            
            places_data.append({
                'id': place.id,
                'name': place.name,
                'latest_image': request.build_absolute_uri(
                    top_post.photo_image.url
                ) if top_post and top_post.photo_image else None,
                'post_count': place.post_count,
                'rating': place.rating,
                'latitude': place.location.y if place.location else None,
                'longitude': place.location.x if place.location else None,
                'favorite_count': Favorites.objects.filter(place=place).count(),
                'total_likes': place.total_likes or 0,  # 総いいね数を追加
            })
        
        return Response({
            'places': places_data,
            'has_next': page_obj.has_next(),
            'total_places': favorite_places.count(),
        })
    except Exception as e:
        logger.error(f"お気に入り場所取得中にエラー: {str(e)}")
        return Response(
            {'error': 'お気に入り場所の取得中にエラーが発生しました。'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )
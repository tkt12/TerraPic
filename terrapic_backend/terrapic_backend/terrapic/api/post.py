from rest_framework import status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from django.shortcuts import get_object_or_404
from ..models import Posts, Likes
from ..serializers import (
    PostSerializer
)
from ..services import PostService
from ..utils import format_api_error
import json
import logging

logger = logging.getLogger(__name__)

class CreatePostView(APIView):
    """新規投稿を作成するAPIビュー"""
    permission_classes = [IsAuthenticated]
    parser_classes = (MultiPartParser, FormParser, JSONParser)

    def post(self, request):
        """
        新規投稿を作成
        
        必要なデータ:
        - photo_image: 投稿画像
        - place_data: 場所情報（name, latitude, longitude）
        - description: 説明文
        - rating: 評価（オプション）
        - weather: 天気（オプション）
        - season: 季節（オプション）
        """
        try:
            logger.info(f"リクエストデータ: {request.data}")
            logger.info(f"ファイルデータ: {request.FILES}")

            # 場所情報の取得
            place_data = json.loads(request.data.get('place_data', '{}'))
            image_file = request.FILES.get('photo_image')
            
            # 必要なデータの存在確認
            if not image_file or not place_data:
                return Response(
                    format_api_error('画像と場所情報は必須です。'),
                    status=status.HTTP_400_BAD_REQUEST
                )

            # PostServiceを使用して投稿を作成
            post = PostService.create_post(
                user=request.user,
                image_file=image_file,
                place_data=place_data,
                description=request.data.get('description', ''),
                rating=request.data.get('rating'),
                weather=request.data.get('weather'),
                season=request.data.get('season')
            )

            serializer = PostSerializer(post)
            return Response(
                serializer.data, 
                status=status.HTTP_201_CREATED
            )

        except ValueError as e:
            return Response(
                format_api_error(str(e)),
                status=status.HTTP_400_BAD_REQUEST
            )
        except Exception as e:
            logger.error(f"投稿作成中にエラー: {str(e)}")
            return Response(
                format_api_error('投稿の作成中にエラーが発生しました。'),
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

class LikeView(APIView):
    """投稿へのいいねを管理するAPIビュー"""
    permission_classes = [IsAuthenticated]

    def post(self, request, post_id):
        """いいねの追加・削除を切り替え"""
        try:
            # PostServiceを使用していいねを切り替え
            is_liked = PostService.toggle_like(
                user=request.user,
                post_id=post_id
            )
            
            if is_liked:
                status_msg = 'liked'
                message = 'いいねしました'
            else:
                status_msg = 'unliked'
                message = 'いいねを解除しました'

            # 最新のいいね数を取得
            post = Posts.objects.get(id=post_id)
            
            return Response({
                'status': status_msg,
                'like_count': post.like_count,
                'message': message
            })

        except Posts.DoesNotExist:
            return Response(
                format_api_error('投稿が見つかりません'),
                status=status.HTTP_404_NOT_FOUND
            )
        except Exception as e:
            logger.error(f"いいね処理中にエラー: {str(e)}")
            return Response(
                format_api_error('いいねの処理中にエラーが発生しました'),
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

class LikeStatusView(APIView):
    """投稿のいいね状態を確認するAPIビュー"""
    permission_classes = [IsAuthenticated]

    def get(self, request, post_id):
        """いいね状態を取得"""
        try:
            post = get_object_or_404(Posts, id=post_id)
            is_liked = Likes.objects.filter(
                user=request.user,
                post=post
            ).exists()
            
            # 投稿画像のURL構築
            post_image_url = None
            if post.photo_image:
                post_image_url = request.build_absolute_uri(
                    post.photo_image.url
                )
            
            return Response({
                'is_liked': is_liked,
                'like_count': post.like_count,
                'post': {
                    'id': post.id,
                    'image_url': post_image_url,
                    'description': post.description,
                    'user': {
                        'username': post.user.username,
                        'profile_image': request.build_absolute_uri(
                            post.user.profile_image.url
                        ) if post.user.profile_image else None,
                    }
                }
            })

        except Posts.DoesNotExist:
            return Response(
                format_api_error('投稿が見つかりません'),
                status=status.HTTP_404_NOT_FOUND
            )
        except Exception as e:
            logger.error(f"いいね状態取得中にエラー: {str(e)}")
            return Response(
                format_api_error('いいね状態の取得中にエラーが発生しました'),
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def delete_post(request, post_id):
    """投稿を削除するAPI"""
    try:
        post = get_object_or_404(Posts, id=post_id)

        # 投稿者本人のみ削除可能
        if post.user != request.user:
            return Response(
                format_api_error('この投稿を削除する権限がありません'),
                status=status.HTTP_403_FORBIDDEN
            )

        # PostServiceを使用して投稿を削除
        PostService.delete_post(post_id)

        return Response(status=status.HTTP_204_NO_CONTENT)

    except Posts.DoesNotExist:
        return Response(
            format_api_error('投稿が見つかりません'),
            status=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"投稿削除中にエラー: {str(e)}")
        return Response(
            format_api_error('投稿の削除中にエラーが発生しました'),
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

@api_view(['PUT', 'PATCH'])
@permission_classes([IsAuthenticated])
def update_post(request, post_id):
    """投稿を更新するAPI"""
    try:
        post = get_object_or_404(Posts, id=post_id)

        # 投稿者本人のみ更新可能
        if post.user != request.user:
            return Response(
                format_api_error('この投稿を更新する権限がありません'),
                status=status.HTTP_403_FORBIDDEN
            )

        # 更新可能なフィールド
        if 'description' in request.data:
            post.description = request.data['description']
        if 'rating' in request.data:
            post.rating = request.data['rating']
        if 'weather' in request.data:
            post.weather = request.data['weather'] or ''
        if 'season' in request.data:
            post.season = request.data['season'] or ''

        post.save()

        serializer = PostSerializer(post)
        return Response(serializer.data)

    except Posts.DoesNotExist:
        return Response(
            format_api_error('投稿が見つかりません'),
            status=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"投稿更新中にエラー: {str(e)}")
        return Response(
            format_api_error('投稿の更新中にエラーが発生しました'),
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )
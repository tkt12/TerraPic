from rest_framework import status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated, AllowAny
from django.shortcuts import get_object_or_404
from django.db.models import Count, Avg
from ..models import Places, Favorites, Posts, Likes
from ..serializers import (
    PlaceWithPostsSerializer, TopPhotoSerializer,
    PlaceSearchSerializer
)
from ..services import PlaceService
from ..utils import format_api_error
import logging
import requests

logger = logging.getLogger(__name__)

from rest_framework import status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny
from django.contrib.gis.geos import Polygon
from django.db.models import Count
from django.db.models import Prefetch
from ..models import Places, Posts
import logging

logger = logging.getLogger(__name__)

class NearbyPlacesView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        try:
            min_lat = request.GET.get('min_lat')
            max_lat = request.GET.get('max_lat')
            min_lon = request.GET.get('min_lon')
            max_lon = request.GET.get('max_lon')

            logger.debug(f"Received bbox parameters: min_lat={min_lat}, max_lat={max_lat}, min_lon={min_lon}, max_lon={max_lon}")

            if not all([min_lat, max_lat, min_lon, max_lon]):
                return Response({'error': 'Missing required parameters.'}, status=status.HTTP_400_BAD_REQUEST)

            places = self.get_places_by_bbox(min_lat, max_lat, min_lon, max_lon)
            
            places = places.annotate(
                posts_count=Count('posts', distinct=True),
                favorites_count=Count('favorites', distinct=True),
            ).prefetch_related(
                Prefetch(
                    'posts',
                    queryset=Posts.objects.exclude(photo_spot_location__isnull=True),
                    to_attr='location_posts'
                )
            )

            logger.debug(f"Found {places.count()} places")

            serializer = PlaceWithPostsSerializer(
                places, 
                many=True,
                context={'request': request}
            )
            return Response(serializer.data)

        except ValueError as e:
            logger.error(f"Invalid parameter values: {str(e)}")
            return Response(
                {'error': '不正なパラメータです'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        except Exception as e:
            logger.error(f"Error in NearbyPlacesView: {str(e)}")
            return Response(
                {'error': '場所の取得中にエラーが発生しました'}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    def get_places_by_bbox(self, min_lat, max_lat, min_lon, max_lon):
        """
        バウンディングボックス内の場所を取得する

        Args:
            min_lat (str): 最小緯度
            max_lat (str): 最大緯度
            min_lon (str): 最小経度
            max_lon (str): 最大経度

        Returns:
            QuerySet: 条件に合致する場所のクエリセット
        """
        try:
            min_lat, max_lat = float(min_lat), float(max_lat)
            min_lon, max_lon = float(min_lon), float(max_lon)
            
            bbox = Polygon.from_bbox((min_lon, min_lat, max_lon, max_lat))
            places = Places.objects.filter(location__within=bbox)
            
            return places
            
        except ValueError:
            raise ValueError('緯度経度の値が不正です')


class PlaceSearchView(APIView):
    """投稿用の場所検索APIビュー"""
    
    def get(self, request):
        try:
            query = request.query_params.get('q', '')
            lat = request.query_params.get('lat')
            lon = request.query_params.get('lon')

            if not query:
                return Response(
                    {"error": "検索クエリが必要です。"}, 
                    status=status.HTTP_400_BAD_REQUEST
                )

            try:
                places = PlaceService.search_places_for_post(query, lat, lon)
                serializer = PlaceSearchSerializer(places, many=True)
                return Response(serializer.data)
            except Exception as api_error:
                # 一時的なエラーメッセージ
                return Response(
                    {
                        "error": "現在、外部の場所検索サービスが利用できません。",
                        "detail": str(api_error)
                    },
                    status=status.HTTP_503_SERVICE_UNAVAILABLE
                )

        except Exception as e:
            logger.error(f"場所検索中にエラー: {str(e)}")
            return Response(
                {'error': '検索中にエラーが発生しました。'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

class FavoriteView(APIView):
    """お気に入り登録・解除を管理するAPIビュー"""
    permission_classes = [IsAuthenticated]

    def post(self, request, place_id):
        """お気に入りの登録・解除を切り替え"""
        try:
            place = get_object_or_404(Places, id=place_id)
            favorite, created = Favorites.objects.get_or_create(
                user=request.user,
                place=place
            )
            
            if not created:
                favorite.delete()
                return Response({
                    'status': 'unfavorited',
                    'favorite_count': place.favorite_count
                })
                
            return Response({
                'status': 'favorited',
                'favorite_count': place.favorite_count
            })

        except Exception as e:
            logger.error(f"お気に入り処理中にエラー: {str(e)}")
            return Response(
                format_api_error('お気に入り処理中にエラーが発生しました。'),
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

class FavoriteStatusView(APIView):
    """お気に入り状態を確認するAPIビュー"""
    permission_classes = [IsAuthenticated]

    def get(self, request, place_id):
        """お気に入り状態を取得"""
        try:
            place = get_object_or_404(Places, id=place_id)
            is_favorited = Favorites.objects.filter(
                user=request.user,
                place=place
            ).exists()
            
            return Response({
                'is_favorite': is_favorited,
                'favorite_count': place.favorite_count
            })

        except Exception as e:
            logger.error(f"お気に入り状態取得中にエラー: {str(e)}")
            return Response(
                format_api_error('お気に入り状態の取得中にエラーが発生しました。'),
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

@api_view(['GET'])
@permission_classes([AllowAny])
def get_top_photo(request, place_id):
    """場所のトップ写真を取得するAPI"""
    try:
        # 場所の存在確認
        place = get_object_or_404(Places, id=place_id)
        
        # 写真スポットの位置情報を取得
        latitude = request.query_params.get('latitude')
        longitude = request.query_params.get('longitude')
        
        if latitude and longitude:
            # 特定の撮影位置での投稿を取得
            post = PlaceService.get_photo_at_location(
                place_id, float(latitude), float(longitude)
            )
        else:
            # 最もいいねの多い投稿を取得
            post = PlaceService.get_top_rated_photo(place_id)

        if not post:
            return Response(
                {'error': 'この場所の写真が見つかりません'},
                status=status.HTTP_404_NOT_FOUND
            )

        serializer = TopPhotoSerializer(post, context={'request': request})
        
        return Response({
            'image_url': serializer.data['image_url'],
            'name': place.name,
            'favorite_count': place.favorite_count,
            'rating': str(place.rating) if place.rating is not None else '未評価'
        })

    except Exception as e:
        logger.error(f"トップ写真取得中にエラー: {str(e)}")
        return Response(
            {'error': '写真の取得中にエラーが発生しました'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

@api_view(['GET'])
@permission_classes([AllowAny])
def place_details(request, place_id):
    """
    場所の詳細情報を取得するAPI
    """
    try:
        place = Places.objects.get(id=place_id)
        
        # 評価の分布を計算
        posts = Posts.objects.filter(place=place)
        total_ratings = posts.count()

        # トップ画像の取得（いいね数が最も多い投稿の画像）
        top_post = posts.order_by('-like_count', '-created_at').first()
        image_url = None
        if top_post and top_post.photo_image:
            image_url = request.build_absolute_uri(top_post.photo_image.url)

        if total_ratings > 0:
            # 各評価の件数を取得
            ratings_distribution = {
                rating: posts.filter(rating=rating).count()
                for rating in range(1, 6)
            }
            
            rating_percentages = {
                'five_star': round((ratings_distribution[5] / total_ratings) * 100, 1),
                'four_star': round((ratings_distribution[4] / total_ratings) * 100, 1),
                'three_star': round((ratings_distribution[3] / total_ratings) * 100, 1),
                'two_star': round((ratings_distribution[2] / total_ratings) * 100, 1),
                'one_star': round((ratings_distribution[1] / total_ratings) * 100, 1),
            }
        else:
            rating_percentages = {f"{i}_star": 0.0 for i in range(1, 6)}

        # 写真の取得（いいね順）
        photos = posts.order_by('-like_count', '-created_at')
        photo_data = [{
            'id': post.id,
            'url': request.build_absolute_uri(post.photo_image.url),
            'likes': post.like_count,
            'is_liked': Likes.objects.filter(
                user=request.user, 
                post=post
            ).exists() if request.user.is_authenticated else False,
            'created_at': post.created_at.isoformat(),
            'user': {
                'id': post.user.id,
                'username': post.user.username,
                'profile_image': request.build_absolute_uri(
                    post.user.profile_image.url
                ) if post.user.profile_image else None,
            },
            'description': post.description,
            'photo_spot_location': {
                'type': 'Point',
                'coordinates': [
                    post.photo_spot_location.x,
                    post.photo_spot_location.y
                ]
            } if post.photo_spot_location else None
        } for post in photos]

        response_data = {
            'id': place.id,
            'name': place.name,
            'image_url': image_url,  # トップ画像URLを追加
            'rating': str(place.rating) if place.rating is not None else 'N/A',
            'total_reviews': total_ratings,
            'rating_distribution': rating_percentages,
            'favorite_count': place.favorite_count,
            'photos': photo_data,
            'latitude': place.location.y,
            'longitude': place.location.x,
        }
        
        return Response(response_data)

    except Places.DoesNotExist:
        return Response(
            {"error": "場所が見つかりません"}, 
            status=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"場所詳細の取得中にエラー: {str(e)}")
        return Response(
            {"error": "内部サーバーエラー"}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )
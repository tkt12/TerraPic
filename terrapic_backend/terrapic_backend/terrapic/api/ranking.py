from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework import status
from ..serializers import (
    PlaceRankingSerializer,
    PostRankingSerializer,
)
from ..services import PlaceService, PostService, ProfileService
from ..utils import format_api_error
import logging

logger = logging.getLogger(__name__)

@api_view(['GET'])
@permission_classes([AllowAny])
def places_ranking(request):
    """
    人気の場所ランキングを取得するAPI
    
    Parameters:
        period: ランキング期間（weekly/monthly/all）
        limit: 取得件数
    """
    try:
        period = request.GET.get('period', 'all')
        limit = int(request.GET.get('limit', 10))
        
        # PlaceServiceを使用してランキングデータを取得
        ranked_places = PlaceService.get_ranking(
            period=period,
            limit=limit
        )

        serializer = PlaceRankingSerializer(
            ranked_places,
            many=True,
            context={'request': request}
        )
        
        return Response(serializer.data)

    except ValueError as e:
        return Response(
            format_api_error(str(e)),
            status=status.HTTP_400_BAD_REQUEST
        )
    except Exception as e:
        logger.error(f"場所ランキング取得中にエラー: {str(e)}")
        return Response(
            format_api_error('ランキングの取得中にエラーが発生しました。'),
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

@api_view(['GET'])
@permission_classes([AllowAny])
def posts_ranking(request):
    """
    人気の投稿ランキングを取得するAPI
    
    Parameters:
        period: ランキング期間（weekly/monthly/all）
        limit: 取得件数
    """
    try:
        period = request.GET.get('period', 'all')
        limit = int(request.GET.get('limit', 10))
        
        # PostServiceを使用してランキングデータを取得
        ranked_posts = PostService.get_ranking(
            period=period,
            limit=limit
        )

        serializer = PostRankingSerializer(
            ranked_posts,
            many=True,
            context={'request': request}
        )
        
        return Response(serializer.data)

    except ValueError as e:
        return Response(
            format_api_error(str(e)),
            status=status.HTTP_400_BAD_REQUEST
        )
    except Exception as e:
        logger.error(f"投稿ランキング取得中にエラー: {str(e)}")
        return Response(
            format_api_error('ランキングの取得中にエラーが発生しました。'),
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )
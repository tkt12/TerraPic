from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import authenticate
from django.contrib.gis.geos import Point
from django.views.decorators.csrf import csrf_exempt
from django.db.models import Count
from ..models import Places, Notifications
from ..forms import CustomSignupForm
import logging

logger = logging.getLogger(__name__)

@api_view(['POST'])
@permission_classes([AllowAny])
def login_api(request):
    """
    ログイン処理を行うAPI
    
    Parameters:
        email: メールアドレス
        password: パスワード
        
    Returns:
        refresh: リフレッシュトークン
        access: アクセストークン
    """
    try:
        email = request.data.get('email')
        password = request.data.get('password')
        
        # 入力値の検証
        if not email or not password:
            return Response(
                {'error': 'メールアドレスとパスワードは必須です。'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # 認証処理
        user = authenticate(email=email, password=password)
        
        if user:
            # トークンの生成
            refresh = RefreshToken.for_user(user)
            return Response({
                'refresh': str(refresh),
                'access': str(refresh.access_token),
            })
            
        return Response(
            {'error': '認証に失敗しました。'},
            status=status.HTTP_401_UNAUTHORIZED
        )
        
    except Exception as e:
        logger.error(f"ログイン処理中にエラー: {str(e)}")
        return Response(
            {'error': 'ログイン処理中にエラーが発生しました。'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

@csrf_exempt
@api_view(['POST'])
@permission_classes([AllowAny])
def signup_api(request):
    """
    サインアップ処理を行うAPI
    
    Parameters:
        email: メールアドレス
        password1: パスワード
        password2: パスワード（確認用）
        username: ユーザー名
        name: 表示名
        profile_image: プロフィール画像（オプション）
        
    Returns:
        refresh: リフレッシュトークン
        access: アクセストークン
    """
    try:
        logger.info("サインアップAPI呼び出し")
        logger.info(f"リクエストデータ: {request.data}")
        
        # フォームバリデーション
        form = CustomSignupForm(request.data)
        if form.is_valid():
            # ユーザーの作成
            user = form.save(request)
            refresh = RefreshToken.for_user(user)
            logger.info(f"ユーザー作成成功: {user.username}")
            
            return Response({
                'refresh': str(refresh),
                'access': str(refresh.access_token),
            }, status=status.HTTP_201_CREATED)
        else:
            logger.warning(f"フォームバリデーションエラー: {form.errors}")
            return Response(
                form.errors,
                status=status.HTTP_400_BAD_REQUEST
            )
            
    except Exception as e:
        logger.exception(f"サインアップ処理中に予期せぬエラー: {str(e)}")
        return Response({
            'error': 'サインアップ処理中にエラーが発生しました。',
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def home(request):
    """
    ホーム画面の情報を取得するAPI
    
    Parameters:
        latitude: 現在地の緯度
        longitude: 現在地の経度
        
    Returns:
        user_location: ユーザーの現在地
        nearby_places: 近くの場所一覧
        unread_notifications: 未読通知数
    """
    try:
        # 位置情報の取得
        user_lat = float(request.GET.get('latitude', 0))
        user_lon = float(request.GET.get('longitude', 0))
        
        # 現在地の設定
        user_location = Point(user_lon, user_lat, srid=4326)
        
        # 検索半径（km）
        search_radius = 10
        
        # 近くの場所を取得
        nearby_places = Places.nearby_places(user_location, search_radius)
        
        # レスポンスデータの整形
        places_data = [{
            'id': place.id,
            'name': place.name,
            'latitude': place.location.y,
            'longitude': place.location.x,
            'rating': float(place.rating) if place.rating else None,
            'distance': place.distance.km
        } for place in nearby_places]
        
        # 未読通知数の取得
        unread_notifications = Notifications.objects.filter(
            user=request.user,
            is_read=False
        ).count()
        
        response_data = {
            'user_location': {
                'latitude': user_lat,
                'longitude': user_lon
            },
            'nearby_places': places_data,
            'unread_notifications': unread_notifications
        }
        
        return Response(response_data)
        
    except ValueError as e:
        logger.error(f"位置情報の形式が不正: {str(e)}")
        return Response(
            {'error': '位置情報の形式が不正です。'},
            status=status.HTTP_400_BAD_REQUEST
        )
    except Exception as e:
        logger.error(f"ホーム画面データ取得中にエラー: {str(e)}")
        return Response(
            {'error': 'データの取得中にエラーが発生しました。'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )
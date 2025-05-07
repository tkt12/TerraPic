from django.contrib.gis.geos import Point, Polygon
from django.contrib.gis.measure import D
from django.db.models import Count, Avg, Q, Prefetch
from django.core.cache import cache
from ..models import Places, Posts
from ..utils import validate_location_data, get_period_filter
import logging
import requests

logger = logging.getLogger(__name__)

class PlaceService:
    """場所に関連するビジネスロジックを管理するサービスクラス"""
    
    @staticmethod
    def find_nearby_places(latitude, longitude, radius_km=5):
        """
        指定された位置の近くにある場所を検索する
        
        Args:
            latitude: 緯度
            longitude: 経度
            radius_km: 検索半径（km）
        """
        try:
            validate_location_data(latitude, longitude)
            
            user_location = Point(float(longitude), float(latitude))
            cache_key = f'nearby_places_{latitude}_{longitude}_{radius_km}'
            
            # キャッシュをチェック
            cached_results = cache.get(cache_key)
            if cached_results:
                return cached_results

            # 近くの場所を検索
            places = Places.objects.filter(
                location__distance_lte=(user_location, D(km=radius_km))
            ).annotate(
                distance=D('location', user_location),
                post_count=Count('posts'),
                avg_rating=Avg('posts__rating')
            ).order_by('distance')

            # 結果をキャッシュ（5分間）
            cache.set(cache_key, places, 300)
            
            return places

        except Exception as e:
            logger.error(f"近くの場所検索中にエラー: {str(e)}")
            raise

    @staticmethod
    def find_places_in_bounds(min_lat, max_lat, min_lon, max_lon):
        """
        指定された境界ボックス内の場所を検索する
        
        Args:
            min_lat: 最小緯度
            max_lat: 最大緯度
            min_lon: 最小経度
            max_lon: 最大経度
        """
        try:
            bbox = Polygon.from_bbox((min_lon, min_lat, max_lon, max_lat))
            
            places = Places.objects.filter(
                location__within=bbox
            ).annotate(
                post_count=Count('posts'),
                favorites_count=Count('favorites')
            )
            
            return places

        except Exception as e:
            logger.error(f"境界ボックス内の場所検索中にエラー: {str(e)}")
            raise


    @staticmethod
    def get_photo_at_location(place_id, latitude, longitude):
        """
        特定の位置での投稿写真を取得
        
        Args:
            place_id: 場所のID
            latitude: 緯度
            longitude: 経度
            
        Returns:
            Posts: 投稿オブジェクト（見つからない場合はNone）
        """
        try:
            location = Point(longitude, latitude, srid=4326)
            return Posts.objects.filter(
                place_id=place_id,
                photo_spot_location=location
            ).order_by('-like_count', '-created_at').first()
        except Exception as e:
            logger.error(f"特定位置での写真取得中にエラー: {str(e)}")
            return None

    @staticmethod
    def get_top_rated_photo(place_id):
        """
        場所の中で最も評価の高い写真を取得
        
        Args:
            place_id: 場所のID
            
        Returns:
            Posts: 投稿オブジェクト（見つからない場合はNone）
        """
        try:
            return Posts.objects.filter(
                place_id=place_id
            ).order_by('-like_count', '-created_at').first()
        except Exception as e:
            logger.error(f"トップ写真取得中にエラー: {str(e)}")
            return None

    @staticmethod
    def get_place_photos(place_id, page=1, per_page=10):
        """
        場所の写真一覧を取得
        
        Args:
            place_id: 場所のID
            page: ページ番号
            per_page: 1ページあたりの写真数
            
        Returns:
            tuple: (写真リスト, 総数)
        """
        try:
            photos = Posts.objects.filter(
                place_id=place_id
            ).order_by('-created_at')
            
            start_idx = (page - 1) * per_page
            end_idx = start_idx + per_page
            
            return photos[start_idx:end_idx], photos.count()
        except Exception as e:
            logger.error(f"写真一覧取得中にエラー: {str(e)}")
            raise

    @staticmethod
    def get_place_details(place_id):
        """
        場所の詳細情報を取得する
        
        Args:
            place_id: 場所のID
            
        Returns:
            dict: 場所の詳細情報と写真一覧を含む辞書
        """
        try:
            place = Places.objects.get(id=place_id)
            
            # 投稿を取得（いいね数順）
            posts = Posts.objects.filter(
                place=place
            ).order_by('-like_count', '-created_at')
            
            total_ratings = posts.count()

            # 評価の分布を計算
            if total_ratings > 0:
                ratings_distribution = {
                    rating: posts.filter(rating=rating).count()
                    for rating in range(1, 6)
                }
                
                rating_percentages = {
                    f"{rating}_star": (count / total_ratings) * 100
                    for rating, count in ratings_distribution.items()
                }
            else:
                rating_percentages = {f"{i}_star": 0 for i in range(1, 6)}

            # トップ画像の取得（いいね数が最も多い投稿）
            top_post = posts.first()
            image_url = top_post.photo_image.url if top_post and top_post.photo_image else None

            # 写真一覧データの作成
            photos_data = []
            for post in posts:
                if post.photo_image:
                    photos_data.append({
                        'id': post.id,
                        'photo_image': post.photo_image.url,
                        'description': post.description,
                        'rating': float(post.rating) if post.rating else None,
                        'like_count': post.like_count,
                        'created_at': post.created_at.isoformat(),
                        'user': {
                            'id': post.user.id,
                            'username': post.user.username,
                            'profile_image': post.user.profile_image.url if post.user.profile_image else None,
                        },
                        'photo_spot_location': {
                            'type': 'Point',
                            'coordinates': [
                                post.photo_spot_location.x,
                                post.photo_spot_location.y
                            ]
                        } if post.photo_spot_location else None
                    })

            return {
                'id': place.id,
                'name': place.name,
                'image_url': image_url,
                'rating': float(place.rating) if place.rating else None,
                'total_reviews': total_ratings,
                'rating_distribution': rating_percentages,
                'favorite_count': place.favorite_count,
                'photos': photos_data,
                'latitude': place.location.y,
                'longitude': place.location.x,
            }

        except Places.DoesNotExist:
            logger.warning(f"場所が見つかりません: ID {place_id}")
            raise
        except Exception as e:
            logger.error(f"場所の詳細取得中にエラー: {str(e)}")
            raise

    @staticmethod
    def update_place_rating(place_id):
        """
        場所の評価を更新する
        
        Args:
            place_id: 場所のID
        """
        try:
            place = Places.objects.get(id=place_id)
            
            # 評価の平均を計算
            avg_rating = Posts.objects.filter(
                place=place
            ).aggregate(Avg('rating'))['rating__avg']
            
            place.rating = avg_rating
            place.save()
            
            return place

        except Places.DoesNotExist:
            logger.warning(f"場所が見つかりません: ID {place_id}")
            raise
        except Exception as e:
            logger.error(f"場所の評価更新中にエラー: {str(e)}")
            raise

    @staticmethod
    @staticmethod
    def search_places(query, limit=15):
        """
        データベースに登録されている場所を検索する
        
        Args:
            query: 検索クエリ
            limit: 取得する結果の最大数
        """
        try:
            logger.debug(f"場所検索開始: query={query}, limit={limit}")
            
            places = Places.objects.filter(
                name__icontains=query
            ).annotate(
                post_count=Count('posts', distinct=True),
                favorites_count=Count('favorites', distinct=True)
            ).prefetch_related(
                Prefetch(
                    'posts',
                    queryset=Posts.objects.order_by('-like_count'),
                    to_attr='top_posts'
                )
            ).order_by('-post_count')[:limit]

            logger.debug(f"検索結果: {places.count()}件")
            return places

        except Exception as e:
            logger.error(f"場所検索中にエラー: {str(e)}")
            raise

    @staticmethod
    def search_places_for_post(query, lat=None, lon=None, limit=10):
        """
        Google Places APIを使用して投稿用の場所を検索する
        
        Args:
            query: 検索クエリ
            lat: 現在地の緯度（オプション）
            lon: 現在地の経度（オプション）
            limit: 取得する結果の最大数
        """
        try:
            API_KEY = 'SECRET_API_KEY'
            url = f'https://maps.googleapis.com/maps/api/place/textsearch/json?query={query}&key={API_KEY}&language=ja'
            
            if lat and lon:
                url += f'&location={lat},{lon}&radius=5000'

            response = requests.get(url)
            response_data = response.json()
            
            # APIのステータスチェックを追加
            if response_data.get('status') == 'REQUEST_DENIED':
                logger.error(f"Google Places API request denied: {response_data.get('error_message')}")
                raise Exception('Google Places API service is currently unavailable')
                
            if response.status_code == 200 and response_data.get('status') == 'OK':
                results = response_data.get('results', [])
                places = []
                
                for place in results[:limit]:
                    place_data = {
                        'id': place['place_id'],
                        'name': place['name'],
                        'latitude': place['geometry']['location']['lat'],
                        'longitude': place['geometry']['location']['lng'],
                        'formatted_address': place.get('formatted_address', ''),
                        'is_google_place': True
                    }
                    places.append(place_data)
                    
                return places
                
            logger.error(f"API Error: {response_data.get('status')} - {response_data.get('error_message', '')}")
            return []

        except Exception as e:
            logger.error(f"Google Places API検索中にエラー: {str(e)}")
            raise

    @staticmethod
    def get_search_suggestions(query, limit=5):
        """
        場所名のサジェストを取得する
        
        Args:
            query: 検索クエリ
            limit: 取得件数の上限
            
        Returns:
            QuerySet: サジェスト候補の場所リスト
        """
        try:
            return Places.objects.filter(
                name__istartswith=query
            ).annotate(
                post_count=Count('posts')
            ).order_by(
                '-post_count'
            )[:limit]

        except Exception as e:
            logger.error(f"場所サジェスト取得中にエラー: {str(e)}")
            raise

    @staticmethod
    def get_ranking(period='all', limit=10):
        """
        場所のランキングを取得する
        
        Args:
            period: ランキング期間（weekly/monthly/all）
            limit: 取得件数
        """
        try:
            period_filter = get_period_filter(period, 'Places')
            
            places = Places.objects.annotate(
                post_count=Count('posts', filter=period_filter, distinct=True),
                favorites_count=Count('favorites', distinct=True)  # periodフィルターを一時的に除外
            ).filter(
                Q(post_count__gt=0) | Q(favorites_count__gt=0)
            ).order_by(
                '-favorites_count',
                '-post_count'
            )[:limit]

            return places

        except Exception as e:
            logger.error(f"場所ランキング取得中にエラー: {str(e)}")
            raise
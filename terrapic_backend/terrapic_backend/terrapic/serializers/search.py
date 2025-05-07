import logging

logger = logging.getLogger(__name__)

class SearchSerializer:
    """
    検索結果を統一されたフォーマットで返すためのカスタムシリアライザー
    """
    
    @classmethod
    def format_user(cls, user, request):
        """
        ユーザー情報のフォーマット
        
        Args:
            user: ユーザーオブジェクト
            request: リクエストオブジェクト
        """
        return {
            'id': user.id,
            'type': 'user',  # 検索結果の種類を明示
            'username': user.username,
            'name': user.name,
            'profile_image': request.build_absolute_uri(
                user.profile_image.url
            ) if user.profile_image else None,
            'post_count': getattr(user, 'post_count', 0),
            'follower_count': getattr(user, 'follower_count', 0),
            'link': f'/users/{user.id}',  # ユーザープロフィールへのリンク
        }

    @classmethod
    def format_post(cls, post, request):
        """投稿情報のフォーマット"""
        return {
            'id': str(post.id),
            'type': 'post',
            'photo_image': request.build_absolute_uri(
                post.photo_image.url
            ) if post.photo_image else None,
            'description': post.description,
            'like_count': post.like_count,
            'created_at': post.created_at.isoformat(),
            'user': {
                'id': post.user.id,
                'username': post.user.username,
                'profile_image': request.build_absolute_uri(
                    post.user.profile_image.url
                ) if post.user.profile_image else None
            },
            'place': {
                'id': post.place.id,
                'name': post.place.name
            } if post.place else None
        }

    @classmethod
    def format_place(cls, place, request, top_post=None):
        """
        場所情報のフォーマット
        
        Args:
            place: 場所オブジェクト（Placesモデルインスタンスまたは辞書）
            request: リクエストオブジェクト
            top_post: トップ投稿（オプション）
        """
        try:
            # 辞書型の場合（Google Places APIの結果）
            if isinstance(place, dict):
                return {
                    'id': str(place.get('id') or place.get('place_id')),
                    'type': 'place',
                    'name': place.get('name'),
                    'image_url': None,  # Google Places APIからは画像を取得しない
                    'post_count': 0,
                    'favorite_count': 0,
                    'rating': None,
                    'formatted_address': place.get('formatted_address'),
                    'location': {
                        'latitude': place.get('latitude') or place.get('geometry', {}).get('location', {}).get('lat'),
                        'longitude': place.get('longitude') or place.get('geometry', {}).get('location', {}).get('lng')
                    } if place.get('latitude') or place.get('geometry') else None
                }
            
            # Placesモデルインスタンスの場合
            return {
                'id': str(place.id),
                'type': 'place',
                'name': place.name,
                'image_url': request.build_absolute_uri(
                    top_post.photo_image.url
                ) if top_post and top_post.photo_image else None,
                'post_count': getattr(place, 'post_count', 0),
                'favorite_count': getattr(place, 'favorites_count', 0),
                'rating': float(place.rating) if place.rating else None,
                'location': {
                    'latitude': place.location.y if place.location else None,
                    'longitude': place.location.x if place.location else None
                } if hasattr(place, 'location') else None
            }
                
        except Exception as e:
            logger.error(f"場所フォーマット中にエラー: {str(e)}")
            # エラーが発生した場合は最小限の情報を返す
            return {
                'id': str(getattr(place, 'id', 'unknown')),
                'type': 'place',
                'name': getattr(place, 'name', 'Unknown Place'),
                'error': 'Failed to format place data'
            }
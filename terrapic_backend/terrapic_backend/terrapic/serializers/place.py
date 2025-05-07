from rest_framework import serializers
from ..models import Places, Posts, Favorites
from django.db.models import Sum

from rest_framework import serializers
from django.db.models import Sum
from ..models import Places, Posts, Favorites

class PlaceSerializer(serializers.ModelSerializer):
    """
    場所データの基本的なシリアライズ・デシリアライズを行うシリアライザー
    """
    # お気に入り状態
    is_favorited = serializers.SerializerMethodField()
    # お気に入り数
    favorite_count = serializers.IntegerField(read_only=True)
    # 緯度
    latitude = serializers.SerializerMethodField()
    # 経度
    longitude = serializers.SerializerMethodField()
    # 投稿数
    post_count = serializers.IntegerField(read_only=True)
    # トップ画像URL
    latest_image = serializers.SerializerMethodField()
    # 総いいね数
    total_likes = serializers.SerializerMethodField()

    class Meta:
        model = Places
        fields = [
            'id', 'name', 'latitude', 'longitude', 'rating', 
            'post_count', 'is_favorited', 'favorite_count', 'latest_image',
            'total_likes'
        ]

    def get_latitude(self, obj):
        """緯度を取得"""
        return obj.location.y

    def get_longitude(self, obj):
        """経度を取得"""
        return obj.location.x

    def get_is_favorited(self, obj):
        """現在のユーザーがお気に入り登録しているかを確認"""
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return Favorites.objects.filter(
                user=request.user,
                place=obj
            ).exists()
        return False

    def get_latest_image(self, obj):
        """最新の投稿画像URLを取得"""
        request = self.context.get('request')
        latest_post = Posts.objects.filter(
            place=obj
        ).order_by('-created_at').first()
        
        if latest_post and latest_post.photo_image and request:
            return request.build_absolute_uri(latest_post.photo_image.url)
        return None

    def get_total_likes(self, obj):
        """場所の総いいね数を取得"""
        return Posts.objects.filter(place=obj).aggregate(
            Sum('like_count'))['like_count__sum'] or 0

class PlaceWithPostsSerializer(serializers.ModelSerializer):
    """
    場所データと関連する投稿情報を含むシリアライザー
    """
    latitude = serializers.SerializerMethodField()
    longitude = serializers.SerializerMethodField()
    post_count = serializers.IntegerField(source='posts_count')
    favorite_count = serializers.IntegerField(source='favorites_count')
    posts = serializers.SerializerMethodField()

    class Meta:
        model = Places
        fields = [
            'id', 'name', 'latitude', 'longitude', 'rating', 
            'post_count', 'favorite_count', 'posts'
        ]

    def get_latitude(self, obj):
        """緯度を取得"""
        return obj.location.y if obj.location else None

    def get_longitude(self, obj):
        """経度を取得"""
        return obj.location.x if obj.location else None

    def get_posts(self, obj):
        """場所に関連する投稿情報を取得"""
        from .post import PostLocationSerializer
        posts = getattr(obj, 'location_posts', [])
        return PostLocationSerializer(posts, many=True).data

class PlaceSearchSerializer(serializers.Serializer):
    """
    場所検索結果のシリアライズを行うシリアライザー
    """
    id = serializers.SerializerMethodField()
    name = serializers.CharField()
    latitude = serializers.SerializerMethodField()
    longitude = serializers.SerializerMethodField()
    formatted_address = serializers.CharField(required=False, allow_null=True)
    is_google_place = serializers.BooleanField(default=False)

    def get_id(self, obj):
        """場所IDを取得"""
        return str(obj.get('id') if isinstance(obj, dict) else obj.id)

    def get_latitude(self, obj):
        """緯度を取得"""
        if isinstance(obj, dict):
            return obj.get('latitude')
        return obj.location.y if obj.location else None

    def get_longitude(self, obj):
        """経度を取得"""
        if isinstance(obj, dict):
            return obj.get('longitude')
        return obj.location.x if obj.location else None
    
class TopPhotoSerializer(serializers.ModelSerializer):
    """
    場所のトップ写真を表すシリアライザー
    """
    image_url = serializers.SerializerMethodField()

    class Meta:
        model = Posts
        fields = ['id', 'image_url']

    def get_image_url(self, obj):
        """投稿画像のURLを取得"""
        request = self.context.get('request')
        if obj.photo_image and hasattr(obj.photo_image, 'url'):
            return request.build_absolute_uri(obj.photo_image.url) if request else obj.photo_image.url
        return None


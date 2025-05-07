from rest_framework import serializers
from ..models import Places, Posts

class RankingSerializer(serializers.ModelSerializer):
    """
    ランキングの基本クラス
    """
    rank = serializers.IntegerField(read_only=True)
    
    class Meta:
        model = None
        fields = []

class PlaceRankingSerializer(RankingSerializer):
    """
    場所のランキングシリアライザー
    """
    post_count = serializers.IntegerField()
    favorite_count = serializers.IntegerField(source='favorites_count')
    rating = serializers.SerializerMethodField()
    latest_image = serializers.SerializerMethodField()

    class Meta:
        model = Places
        fields = [
            'id', 'name', 'post_count', 'favorite_count',
            'rating', 'latest_image', 'rank'
        ]

    def get_rating(self, obj):
        """評価値をnullableな数値として返す"""
        if obj.rating is None or obj.rating == '':
            return 0.0
        try:
            return float(obj.rating)
        except (TypeError, ValueError):
            return 0.0

    def get_latest_image(self, obj):
        """最新の投稿画像URLを取得"""
        latest_post = Posts.objects.filter(place=obj).order_by('-created_at').first()
        if latest_post and latest_post.photo_image:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(latest_post.photo_image.url)
        return None

    def to_representation(self, instance):
        """シリアライズ時のデータ変換処理"""
        data = super().to_representation(instance)
        # favorite_countがNoneの場合は0を設定
        if data.get('favorite_count') is None:
            data['favorite_count'] = 0
        return data

class PostRankingSerializer(RankingSerializer):
    """
    投稿のランキングシリアライザー
    """
    user = serializers.SerializerMethodField()
    place = serializers.SerializerMethodField()
    photo_image = serializers.SerializerMethodField()

    class Meta:
        model = Posts
        fields = [
            'id', 'photo_image', 'like_count', 'user', 
            'place', 'created_at', 'rank'
        ]

    def get_user(self, obj):
        """投稿ユーザーの情報を取得"""
        return {
            'id': obj.user.id,
            'username': obj.user.username,
            'profile_image': self.context['request'].build_absolute_uri(
                obj.user.profile_image.url
            ) if obj.user.profile_image else None
        }

    def get_place(self, obj):
        """投稿場所の情報を取得"""
        return {
            'id': obj.place.id,
            'name': obj.place.name
        }

    def get_photo_image(self, obj):
        """投稿画像のURLを取得"""
        if obj.photo_image:
            return self.context['request'].build_absolute_uri(obj.photo_image.url)
        return None
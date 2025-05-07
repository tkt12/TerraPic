from rest_framework import serializers
from django.contrib.gis.geos import Point
from django.core.files.base import ContentFile
from ..models import Posts, Likes
import uuid
import logging

logger = logging.getLogger(__name__)

class PostSerializer(serializers.ModelSerializer):
    """
    投稿データのシリアライズ・デシリアライズを行うシリアライザー
    
    投稿の作成、表示、更新に使用される
    """
    # ユーザー情報（表示用）
    user = serializers.SerializerMethodField()
    # いいね状態
    is_liked = serializers.SerializerMethodField()
    # いいね数
    likes = serializers.IntegerField(source='like_count', read_only=True)
    # ユーザーID（読み取り専用）
    user_id = serializers.IntegerField(source='user.id', read_only=True)
    # 投稿作成時の場所名
    place_name = serializers.CharField(write_only=True)
    # 表示用の場所名
    displayed_place_name = serializers.SerializerMethodField()
    # 緯度・経度（投稿作成時のみ使用）
    latitude = serializers.FloatField(write_only=True)
    longitude = serializers.FloatField(write_only=True)
    # 場所ID（読み取り専用）
    place_id = serializers.IntegerField(source='place.id', read_only=True)
    # 投稿画像（必須）
    photo_image = serializers.ImageField(required=True)
    # 撮影地の位置情報
    photo_spot_location = serializers.SerializerMethodField()

    class Meta:
        model = Posts
        fields = [
            'id', 'user', 'user_id', 'place_name', 'displayed_place_name', 
            'place_id', 'photo_image', 'description', 'rating', 'weather', 
            'season', 'likes', 'is_liked', 'created_at', 'latitude', 'longitude',
            'photo_spot_location',
        ]
        read_only_fields = [
            'id', 'user_id', 'place_id', 'likes', 
            'created_at', 'displayed_place_name', 'photo_spot_location',
        ]

    def get_user(self, obj):
        """投稿ユーザーの情報を取得"""
        return {
            'username': obj.user.username,
            'profile_image': obj.user.profile_image.url if obj.user.profile_image else None
        }
    
    def get_displayed_place_name(self, obj):
        """表示用の場所名を取得"""
        try:
            if obj.place and obj.place.name:
                return obj.place.name
            
            logger.debug(f"Post ID: {obj.id}")
            logger.debug(f"Place: {obj.place}")
            logger.debug(f"Place ID: {obj.place.id if obj.place else 'None'}")
            
            return None
        except Exception as e:
            logger.error(f"場所名の取得中にエラーが発生: post {obj.id}: {str(e)}")
            return None

    def get_is_liked(self, obj):
        """現在のユーザーがいいねしているかを確認"""
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return Likes.objects.filter(user=request.user, post=obj).exists()
        return False
    
    def get_photo_spot_location(self, obj):
        """撮影位置を取得する"""
        if obj.photo_spot_location:
            return {
                'type': 'Point',
                'coordinates': [
                    obj.photo_spot_location.x,
                    obj.photo_spot_location.y
                ]
            }
        return None

    def create(self, validated_data):
        """新しい投稿を作成"""
        try:
            # 位置情報の取得
            latitude = validated_data.pop('latitude')
            longitude = validated_data.pop('longitude')
            place_name = validated_data.pop('place_name')
            
            logger.info(f"場所の処理: {place_name} at {latitude}, {longitude}")
            
            # 場所の作成または取得
            from ..models import Places
            location = Point(longitude, latitude, srid=4326)
            place, created = Places.objects.get_or_create(
                name=place_name,
                defaults={'location': location}
            )
            
            # 既存の場所の位置情報を更新
            if not created and place.location != location:
                place.location = location
                place.save()
                logger.info(f"既存の場所の位置情報を更新: {place.id}")

            # 投稿データの準備
            validated_data['place'] = place
            validated_data['user'] = self.context['request'].user
            
            # 画像の処理
            photo_image = validated_data.get('photo_image')
            if photo_image:
                file_name = f"{uuid.uuid4()}.{photo_image.name.split('.')[-1]}"
                image_content = ContentFile(photo_image.read())
                validated_data['photo_image'] = image_content
                validated_data['photo_image'].name = file_name
            
            # 投稿の作成
            post = Posts.objects.create(**validated_data)
            logger.info(f"投稿を作成: {post.id} for place: {place.id}")
            
            return post
            
        except Exception as e:
            logger.error(f"投稿作成中にエラーが発生: {str(e)}")
            raise serializers.ValidationError(f"投稿の作成に失敗しました: {str(e)}")

    def to_representation(self, instance):
        """投稿データをJSON形式で表現"""
        try:
            data = super().to_representation(instance)
            request = self.context.get('request')
            if request and instance.photo_image:
                data['photo_image'] = request.build_absolute_uri(
                    instance.photo_image.url
                )
            return data
        except Exception as e:
            logger.error(f"データの変換中にエラーが発生: {str(e)}")
            raise serializers.ValidationError("データの処理中にエラーが発生しました")

class PostLocationSerializer(serializers.ModelSerializer):
    """投稿の位置情報を扱うシリアライザー"""
    photo_spot_location = serializers.SerializerMethodField()

    class Meta:
        model = Posts
        fields = ['id', 'photo_spot_location']

    def get_photo_spot_location(self, obj):
        """
        投稿の撮影位置を取得する
        
        Returns:
            dict: 緯度経度情報を含む辞書（位置情報がない場合はNone）
        """
        if obj.photo_spot_location:
            return {
                'latitude': obj.photo_spot_location.y,
                'longitude': obj.photo_spot_location.x
            }
        return None

class LikeSerializer(serializers.ModelSerializer):
    """
    いいねデータのシリアライズ・デシリアライズを行うシリアライザー
    """
    user = serializers.PrimaryKeyRelatedField(read_only=True)
    post = serializers.PrimaryKeyRelatedField(read_only=True)
    
    class Meta:
        model = Likes
        fields = ['id', 'user', 'post', 'created_at']
        read_only_fields = ['created_at']

    def create(self, validated_data):
        """新しいいいねを作成"""
        user = self.context['request'].user
        post = self.context['post']
        return Likes.objects.create(user=user, post=post)

class LikeStatusSerializer(serializers.Serializer):
    """
    いいねの状態を表すシリアライザー
    """
    is_liked = serializers.BooleanField()
    like_count = serializers.IntegerField()
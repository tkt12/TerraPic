from rest_framework import serializers
from django.db.models import Sum
from ..models import Users, Follows
import re
import logging

logger = logging.getLogger(__name__)

class ProfileSerializer(serializers.ModelSerializer):
    """
    ユーザープロフィールのシリアライズ・デシリアライズを行うシリアライザー
    
    プロフィールの表示、編集に使用される
    """
    # プロフィールID（読み取り専用）
    id = serializers.IntegerField(read_only=True)
    # フォロー中のユーザー数
    followed_count = serializers.SerializerMethodField()
    # フォロワー数
    follower_count = serializers.SerializerMethodField()
    # 総いいね数
    total_likes = serializers.SerializerMethodField()
    # プロフィール画像（任意）
    profile_image = serializers.ImageField(required=False, allow_null=True)

    class Meta:
        model = Users
        fields = [
            'id', 'username', 'name', 'profile_image', 'bio',
            'followed_count', 'follower_count', 'total_likes'
        ]

    def get_followed_count(self, obj):
        """フォロー中のユーザー数を取得"""
        return Follows.objects.filter(follower=obj).count()

    def get_follower_count(self, obj):
        """フォロワー数を取得"""
        return Follows.objects.filter(followed=obj).count()

    def get_total_likes(self, obj):
        """ユーザーの投稿が受け取った総いいね数を取得"""
        return obj.posts.aggregate(Sum('like_count'))['like_count__sum'] or 0

    def validate_username(self, value):
        """
        ユーザー名のバリデーション
        - 既存ユーザーとの重複チェック
        - 小文字アルファベットのみ許可
        """
        if Users.objects.filter(username=value).exclude(id=self.instance.id).exists():
            raise serializers.ValidationError("このユーザー名は既に使用されています。")
            
        if not re.match(r'^[a-z0-9_]+$', value):
            raise serializers.ValidationError(
                "ユーザー名は小文字のアルファベット、数字、アンダースコアのみ使用できます。"
            )
        return value

    def validate_name(self, value):
        """
        表示名のバリデーション
        - 最大50文字まで
        """
        if len(value) > 50:
            raise serializers.ValidationError("名前は50文字以内で入力してください。")
        return value

    def validate_bio(self, value):
        """
        自己紹介のバリデーション
        - 最大200文字まで
        """
        if value and len(value) > 200:
            raise serializers.ValidationError("自己紹介は200文字以内で入力してください。")
        return value

    def update(self, instance, validated_data):
        """
        プロフィール情報の更新
        - プロフィール画像の処理を含む
        """
        try:
            # プロフィール画像の処理
            profile_image = validated_data.pop('profile_image', None)
            if profile_image:
                import uuid
                # ユニークなファイル名を生成
                file_name = f"{uuid.uuid4()}.{profile_image.name.split('.')[-1]}"
                
                # 新しい画像コンテンツを作成
                from django.core.files.base import ContentFile
                image_content = ContentFile(profile_image.read())
                
                # 既存の画像を削除
                if instance.profile_image:
                    instance.profile_image.delete(save=False)
                
                # 新しい画像を保存
                instance.profile_image.save(file_name, image_content, save=False)

            # その他のフィールドを更新
            return super().update(instance, validated_data)
            
        except Exception as e:
            logger.error(f"プロフィール更新中にエラーが発生: {str(e)}")
            raise serializers.ValidationError("プロフィールの更新に失敗しました")
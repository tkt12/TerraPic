from django.db.models import Sum, Count
from django.core.files.base import ContentFile
from django.db import transaction
from django.db.models import Q
from ..models import Users, Follows, Posts, Places
from ..utils import (
    validate_image_file,
    generate_unique_filename,
    validate_text_length,
    get_period_filter
)
import logging

logger = logging.getLogger(__name__)

class ProfileService:
    """プロフィールに関連するビジネスロジックを管理するサービスクラス"""

    @staticmethod
    def get_profile_details(user_id):
        """
        ユーザーのプロフィール詳細を取得する
        
        Args:
            user_id: ユーザーID
            
        Returns:
            dict: プロフィール情報と統計データ
        """
        try:
            user = Users.objects.get(id=user_id)
            
            # 統計データの取得
            stats = {
                'total_posts': Posts.objects.filter(user=user).count(),
                'total_likes_received': Posts.objects.filter(user=user).aggregate(
                    total_likes=Sum('like_count')
                )['total_likes'] or 0,
                'followed_count': Follows.objects.filter(follower=user).count(),
                'follower_count': Follows.objects.filter(followed=user).count(),
                'favorite_places_count': Places.objects.filter(
                    favorites__user=user
                ).count()
            }
            
            return {
                'user': user,
                'statistics': stats
            }

        except Users.DoesNotExist:
            logger.warning(f"ユーザーが見つかりません: ID {user_id}")
            raise
        except Exception as e:
            logger.error(f"プロフィール詳細取得中にエラー: {str(e)}")
            raise

    @staticmethod
    @transaction.atomic
    def update_profile(user, profile_data, profile_image=None):
        """
        ユーザープロフィールを更新する
        
        Args:
            user: 更新対象のユーザー
            profile_data: 更新するプロフィール情報
            profile_image: 新しいプロフィール画像（オプション）
            
        Returns:
            Users: 更新されたユーザーオブジェクト
        """
        try:
            # プロフィール画像の処理
            if profile_image:
                validate_image_file(profile_image)
                filename = generate_unique_filename(profile_image.name)
                image_content = ContentFile(profile_image.read())
                
                # 既存の画像を削除
                if user.profile_image:
                    user.profile_image.delete(save=False)
                
                user.profile_image.save(filename, image_content, save=False)

            # ユーザー名の重複チェック
            if 'username' in profile_data:
                username = profile_data['username']
                if Users.objects.filter(username=username).exclude(id=user.id).exists():
                    raise ValueError('このユーザー名は既に使用されています。')
                user.username = username

            # 表示名のバリデーション
            if 'name' in profile_data:
                validate_text_length(profile_data['name'], 50, '表示名')
                user.name = profile_data['name']

            # 自己紹介のバリデーション
            if 'bio' in profile_data:
                validate_text_length(profile_data['bio'], 200, '自己紹介')
                user.bio = profile_data['bio']

            user.save()
            return user

        except Exception as e:
            logger.error(f"プロフィール更新中にエラー: {str(e)}")
            raise

    @staticmethod
    def toggle_follow(follower_id, followed_id):
        """
        フォロー状態を切り替える
        
        Args:
            follower_id: フォローするユーザーのID
            followed_id: フォローされるユーザーのID
            
        Returns:
            tuple: (bool: フォロー状態, int: フォロワー数)
        """
        try:
            # 自分自身をフォローできない
            if follower_id == followed_id:
                raise ValueError('自分自身をフォローすることはできません。')

            follow_relation = Follows.objects.filter(
                follower_id=follower_id,
                followed_id=followed_id
            )

            if follow_relation.exists():
                # フォロー解除
                follow_relation.delete()
                is_following = False
            else:
                # フォロー
                Follows.objects.create(
                    follower_id=follower_id,
                    followed_id=followed_id
                )
                is_following = True

            # 最新のフォロワー数を取得
            follower_count = Follows.objects.filter(
                followed_id=followed_id
            ).count()

            return is_following, follower_count

        except Exception as e:
            logger.error(f"フォロー処理中にエラー: {str(e)}")
            raise

    @staticmethod
    def get_followers(user_id, page=1, per_page=20):
        """
        ユーザーのフォロワー一覧を取得する
        
        Args:
            user_id: ユーザーID
            page: ページ番号
            per_page: 1ページあたりの表示数
            
        Returns:
            tuple: (list: フォロワー一覧, int: 総数)
        """
        try:
            followers = Follows.objects.filter(
                followed_id=user_id
            ).select_related('follower').order_by('-created_at')

            start_idx = (page - 1) * per_page
            end_idx = start_idx + per_page

            return followers[start_idx:end_idx], followers.count()

        except Exception as e:
            logger.error(f"フォロワー取得中にエラー: {str(e)}")
            raise

    @staticmethod
    def get_following(user_id, page=1, per_page=20):
        """
        ユーザーのフォロー中ユーザー一覧を取得する
        
        Args:
            user_id: ユーザーID
            page: ページ番号
            per_page: 1ページあたりの表示数
            
        Returns:
            tuple: (list: フォロー中ユーザー一覧, int: 総数)
        """
        try:
            following = Follows.objects.filter(
                follower_id=user_id
            ).select_related('followed').order_by('-created_at')

            start_idx = (page - 1) * per_page
            end_idx = start_idx + per_page

            return following[start_idx:end_idx], following.count()

        except Exception as e:
            logger.error(f"フォロー中ユーザー取得中にエラー: {str(e)}")
            raise

    @staticmethod
    def search_users(query, limit=10):
        """ユーザーを検索する"""
        try:
            return Users.objects.annotate(
                post_count=Count('posts', distinct=True),
                follower_count=Count('followed', distinct=True),
                following_count=Count('follower', distinct=True)
            ).filter(
                Q(username__icontains=query) |
                Q(name__icontains=query)
            ).order_by(
                '-follower_count',
                '-post_count'
            )[:limit]
        except Exception as e:
            logger.error(f"ユーザー検索中にエラー: {str(e)}")
            raise

    @staticmethod
    def get_search_suggestions(query, limit=5):
        """ユーザー名のサジェストを取得する"""
        try:
            return Users.objects.annotate(
                follower_count=Count('followed', distinct=True)
            ).filter(
                Q(username__istartswith=query) |
                Q(name__istartswith=query)
            ).order_by(
                '-follower_count'
            )[:limit]
        except Exception as e:
            logger.error(f"ユーザーサジェスト取得中にエラー: {str(e)}")
            raise

    @staticmethod
    def get_ranking(period='all', limit=10):
        """
        ユーザーのランキングを取得する
        
        Args:
            period: ランキング期間（weekly/monthly/all）
            limit: 取得件数
        """
        try:
            period_filter = get_period_filter(period, 'Users')
            
            users = Users.objects.annotate(
                total_likes=Sum('posts__like_count', filter=period_filter),
                post_count=Count('posts', filter=period_filter),
                followers_count=Count('followed', filter=period_filter)
            ).filter(
                Q(total_likes__gt=0) | Q(post_count__gt=0)
            ).order_by('-total_likes', '-followers_count')[:limit]

            return users

        except Exception as e:
            logger.error(f"ユーザーランキング取得中にエラー: {str(e)}")
            raise


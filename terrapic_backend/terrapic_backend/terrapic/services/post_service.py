from django.contrib.gis.geos import Point
from django.db.models import F, Window, Q
from django.db.models.functions import DenseRank
from django.core.files.base import ContentFile
from django.db import transaction
from ..models import Posts, Places, Likes
from ..utils import (
    validate_image_file,
    validate_location_data,
    generate_unique_filename,
    get_period_filter
)
import logging

logger = logging.getLogger(__name__)

class PostService:
    """投稿に関連するビジネスロジックを管理するサービスクラス"""

    @staticmethod
    @transaction.atomic
    def create_post(user, image_file, place_data, description, rating=None, weather=None, season=None):
        """
        新しい投稿を作成する
        
        Args:
            user: 投稿ユーザー
            image_file: 投稿画像ファイル
            place_data: 場所情報（name, latitude, longitude）
            description: 投稿の説明文
            rating: 評価（オプション）
            weather: 天気（オプション）
            season: 季節（オプション）
        """
        try:
            # 画像の検証
            validate_image_file(image_file)
            
            # 位置情報の検証
            validate_location_data(
                place_data['latitude'],
                place_data['longitude']
            )

            # 場所の取得または作成
            location = Point(
                float(place_data['longitude']),
                float(place_data['latitude'])
            )
            
            place, _ = Places.objects.get_or_create(
                name=place_data['name'],
                defaults={'location': location}
            )

            # 撮影位置の設定
            photo_spot_location = None
            if 'photo_spot_latitude' in place_data and 'photo_spot_longitude' in place_data:
                photo_spot_location = Point(
                    float(place_data['photo_spot_longitude']),
                    float(place_data['photo_spot_latitude'])
                )

            # 画像の保存処理
            filename = generate_unique_filename(image_file.name)
            image_content = ContentFile(image_file.read())

            # 投稿の作成
            post = Posts.objects.create(
                user=user,
                place=place,
                photo_image=filename,
                description=description,
                rating=rating,
                weather=weather or '',
                season=season or '',
                photo_spot_location=photo_spot_location or location
            )
            
            # 画像コンテンツの保存
            post.photo_image.save(filename, image_content, save=False)
            post.save()

            return post

        except Exception as e:
            logger.error(f"投稿作成中にエラー: {str(e)}")
            raise

    @staticmethod
    def toggle_like(user, post_id):
        """
        投稿のいいねを切り替える
        
        Args:
            user: いいねを行うユーザー
            post_id: 投稿ID
        """
        try:
            post = Posts.objects.get(id=post_id)
            like, created = Likes.objects.get_or_create(
                user=user,
                post=post
            )
            
            if not created:
                # いいねの解除
                like.delete()
                Posts.objects.filter(id=post_id).update(
                    like_count=F('like_count') - 1
                )
                return False
            else:
                # いいねの追加
                Posts.objects.filter(id=post_id).update(
                    like_count=F('like_count') + 1
                )
                return True

        except Posts.DoesNotExist:
            logger.warning(f"投稿が見つかりません: ID {post_id}")
            raise
        except Exception as e:
            logger.error(f"いいね処理中にエラー: {str(e)}")
            raise

    @staticmethod
    def get_user_posts(user_id, page=1, per_page=12):
        """
        ユーザーの投稿一覧を取得する
        
        Args:
            user_id: ユーザーID
            page: ページ番号
            per_page: 1ページあたりの投稿数
        """
        try:
            posts = Posts.objects.filter(
                user_id=user_id,
                deleted_at__isnull=True
            ).select_related(
                'user', 'place'
            ).order_by('-created_at')

            start_idx = (page - 1) * per_page
            end_idx = start_idx + per_page
            
            return posts[start_idx:end_idx], posts.count()

        except Exception as e:
            logger.error(f"ユーザー投稿取得中にエラー: {str(e)}")
            raise

    @staticmethod
    def get_liked_posts(user_id, page=1, per_page=12):
        """
        ユーザーがいいねした投稿一覧を取得する
        
        Args:
            user_id: ユーザーID
            page: ページ番号
            per_page: 1ページあたりの投稿数
        """
        try:
            liked_posts = Posts.objects.filter(
                likes__user_id=user_id,
                deleted_at__isnull=True
            ).select_related(
                'user', 'place'
            ).order_by('-likes__created_at')

            start_idx = (page - 1) * per_page
            end_idx = start_idx + per_page
            
            return liked_posts[start_idx:end_idx], liked_posts.count()

        except Exception as e:
            logger.error(f"いいね投稿取得中にエラー: {str(e)}")
            raise

    @staticmethod
    def search_posts(query, limit=30):
        """
        投稿を検索する
        
        Args:
            query: 検索クエリ
            limit: 取得件数の上限
            
        Returns:
            QuerySet: 検索結果の投稿リスト
        """
        try:
            return Posts.objects.select_related(
                'user', 'place'
            ).filter(
                Q(description__icontains=query) |
                Q(place__name__icontains=query) |
                Q(user__username__icontains=query)
            ).order_by(
                '-created_at'
            )[:limit]

        except Exception as e:
            logger.error(f"投稿検索中にエラー: {str(e)}")
            raise

    @staticmethod
    def get_search_suggestions(query, limit=5):
        """
        投稿の説明文からサジェストを取得する
        
        Args:
            query: 検索クエリ
            limit: 取得件数の上限
            
        Returns:
            QuerySet: サジェスト候補の投稿リスト
        """
        try:
            return Posts.objects.filter(
                description__icontains=query
            ).values('description').distinct().order_by(
                '-like_count'
            )[:limit]

        except Exception as e:
            logger.error(f"投稿サジェスト取得中にエラー: {str(e)}")
            raise

    @staticmethod
    def get_ranking(period='all', limit=10):
        """
        投稿のランキングを取得する

        Args:
            period: ランキング期間（weekly/monthly/all）
            limit: 取得件数
        """
        try:
            period_filter = get_period_filter(period, 'Posts')

            posts = Posts.objects.filter(
                period_filter
            ).select_related(
                'user', 'place'
            ).annotate(
                rank=Window(
                    expression=DenseRank(),
                    order_by=F('like_count').desc()
                )
            ).order_by('rank')[:limit]

            return posts

        except Exception as e:
            logger.error(f"投稿ランキング取得中にエラー: {str(e)}")
            raise

    @staticmethod
    @transaction.atomic
    def delete_post(post_id):
        """
        投稿を削除する

        Args:
            post_id: 削除する投稿のID
        """
        try:
            post = Posts.objects.get(id=post_id)
            post.delete()
            logger.info(f"投稿を削除しました: ID {post_id}")
        except Posts.DoesNotExist:
            logger.warning(f"投稿が見つかりません: ID {post_id}")
            raise
        except Exception as e:
            logger.error(f"投稿削除中にエラー: {str(e)}")
            raise


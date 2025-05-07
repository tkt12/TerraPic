from django.contrib.auth.models import AbstractUser
from django.db import models

class Users(AbstractUser):
    """
    カスタムユーザーモデル
    
    標準のDjangoユーザーモデルを拡張し、TerraPicアプリケーション用にカスタマイズ
    """
    # カスタムフィールド
    username = models.CharField(
        max_length=150, 
        unique=True, 
        null=False, 
        blank=False, 
        default='unknown'
    )
    # ユーザーの表示名
    name = models.CharField(
        max_length=100, 
        default='unknown'
    )
    # ログイン用のメールアドレス
    email = models.EmailField(
        max_length=255, 
        unique=True, 
        null=False, 
        blank=False
    )
    # プロフィール画像
    profile_image = models.ImageField(
        upload_to='profile_images/', 
        null=True, 
        blank=True
    )
    # 自己紹介文
    bio = models.TextField(
        null=True, 
        blank=True
    )
    # 論理削除用のフィールド
    deleted_at = models.DateTimeField(
        null=True, 
        blank=True
    )

    # メールアドレスでログインするための設定
    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['username']

    class Meta:
        db_table = 'users'

    def __str__(self):
        return self.email

    @property
    def posts(self):
        """ユーザーの投稿を取得するプロパティ"""
        from ..models.post import Posts
        return Posts.objects.filter(user=self)

    @property
    def total_likes_received(self):
        """ユーザーの投稿が受け取った総いいね数を取得"""
        from django.db.models import Sum
        return self.posts.aggregate(Sum('like_count'))['like_count__sum'] or 0

    @property
    def followers_info(self):
        """フォロワー情報を取得（プロパティとして使用する場合）"""
        return {
            'count': Follows.objects.filter(followed=self).count(),
            'list': Follows.objects.filter(followed=self)
        }

    @property
    def following_info(self):
        """フォロー中情報を取得（プロパティとして使用する場合）"""
        return {
            'count': Follows.objects.filter(follower=self).count(),
            'list': Follows.objects.filter(follower=self)
        }

    @property
    def favorite_places_count(self):
        """お気に入りの場所の数を取得"""
        from ..models.place import Places
        return Places.objects.filter(favorites__user=self).count()

class Follows(models.Model):
    """
    ユーザー間のフォロー関係を管理するモデル
    """
    # フォロー関係を一意に識別するID
    id = models.AutoField(primary_key=True)
    # フォローする側のユーザー
    follower = models.ForeignKey(
        Users, 
        on_delete=models.CASCADE, 
        related_name='follower'
    )
    # フォローされる側のユーザー
    followed = models.ForeignKey(
        Users, 
        on_delete=models.CASCADE, 
        related_name='followed'
    )
    # フォロー関係が作成された日時
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.follower.name}さんが{self.followed.name}さんをフォロー"

class Notifications(models.Model):
    """
    ユーザーへの通知を管理するモデル
    """
    # 通知を一意に識別するID
    id = models.AutoField(primary_key=True)
    # 通知の受信者
    user = models.ForeignKey(Users, on_delete=models.CASCADE)
    # 通知のタイプ（いいね、フォロー、コメントなど）
    type = models.CharField(max_length=50)
    # 通知の本文
    message = models.TextField()
    # 既読状態
    is_read = models.BooleanField(default=False)
    # 通知が作成された日時
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.message

class Reports_users(models.Model):
    """
    ユーザーの通報を管理するモデル
    """
    # 通報を一意に識別するID
    id = models.AutoField(primary_key=True)
    # 通報したユーザー
    user = models.ForeignKey(Users, on_delete=models.CASCADE)
    # 通報されたユーザー
    reported_user = models.ForeignKey(
        Users, 
        on_delete=models.CASCADE, 
        related_name='reported_user'
    )
    # 通報理由
    reason = models.TextField()
    # 通報された日時
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user.name}さんが{self.reported_user.name}さんを通報"
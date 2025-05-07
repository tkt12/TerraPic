from django.db import models
from django.contrib.gis.db import models as gis_models
from .user import Users
from .place import Places

class Posts(models.Model):
    """
    投稿を管理するモデル
    
    写真、説明、評価などの投稿情報を管理
    """
    # 投稿を一意に識別するID
    id = models.AutoField(primary_key=True)
    # 投稿したユーザー
    user = models.ForeignKey(Users, on_delete=models.CASCADE)
    # 投稿された場所
    place = models.ForeignKey(
        Places, 
        on_delete=models.CASCADE, 
        related_name='posts'
    )
    # 写真を撮影した正確な位置
    photo_spot_location = gis_models.PointField(
        srid=4326, 
        null=True, 
        blank=True
    )
    # 投稿写真
    photo_image = models.ImageField(upload_to='post_images/')
    # 投稿の説明文
    description = models.TextField()
    # 場所の評価（1-5）
    rating = models.DecimalField(
        max_digits=2, 
        decimal_places=1, 
        null=True, 
        blank=True
    )
    # 撮影時の天気
    weather = models.CharField(max_length=100)
    # 撮影時の季節
    season = models.CharField(max_length=100)
    # いいねの数
    like_count = models.IntegerField(default=0)
    # 投稿日時
    created_at = models.DateTimeField(auto_now_add=True)
    # 最終更新日時
    updated_at = models.DateTimeField(auto_now=True)
    # 論理削除用の日時
    deleted_at = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return f"{self.user.username}さんの投稿"

    def save(self, *args, **kwargs):
        """
        投稿保存時に関連する場所の評価を更新
        """
        super().save(*args, **kwargs)
        self.place.update_rating()

class Comments(models.Model):
    """
    投稿へのコメントを管理するモデル
    """
    # コメントを一意に識別するID
    id = models.AutoField(primary_key=True)
    # コメントしたユーザー
    user = models.ForeignKey(Users, on_delete=models.CASCADE)
    # コメントされた投稿
    post = models.ForeignKey(Posts, on_delete=models.CASCADE)
    # コメント本文
    comment = models.TextField()
    # コメント投稿日時
    created_at = models.DateTimeField(auto_now_add=True)
    # 最終更新日時
    updated_at = models.DateTimeField(auto_now=True)
    # 論理削除用の日時
    deleted_at = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return f"{self.user.name}さんのコメント"

class Likes(models.Model):
    """
    投稿へのいいねを管理するモデル
    """
    # いいねを一意に識別するID
    id = models.AutoField(primary_key=True)
    # いいねしたユーザー
    user = models.ForeignKey(Users, on_delete=models.CASCADE)
    # いいねされた投稿
    post = models.ForeignKey(Posts, on_delete=models.CASCADE)
    # いいねされた日時
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user.name}さんのいいね"

class Reports_posts(models.Model):
    """
    投稿の通報を管理するモデル
    """
    # 通報を一意に識別するID
    id = models.AutoField(primary_key=True)
    # 通報したユーザー
    user = models.ForeignKey(Users, on_delete=models.CASCADE)
    # 通報された投稿
    post = models.ForeignKey(Posts, on_delete=models.CASCADE)
    # 通報理由
    reason = models.TextField()
    # 通報された日時
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user.name}さんが{self.post.user.name}さんの投稿を通報"
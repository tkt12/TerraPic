from django.db import models
from django.contrib.gis.db import models as gis_models
from django.contrib.gis.geos import Point, Polygon
from django.contrib.gis.measure import D
from django.contrib.gis.db.models.functions import Distance
from .user import Users

class Places(models.Model):
    """
    撮影場所を管理するモデル
    
    位置情報と評価を含む撮影スポットの情報を管理
    """
    # 場所を一意に識別するID
    id = models.AutoField(primary_key=True)
    # 場所の名称
    name = models.CharField(max_length=255)
    # 位置情報（緯度・経度）
    location = gis_models.PointField(srid=4326, default=Point(0, 0))
    # 場所の評価（平均）
    rating = models.DecimalField(
        max_digits=3, 
        decimal_places=2, 
        null=True, 
        blank=True
    )

    class Meta:
        # 検索を高速化するためのインデックス
        indexes = [
            models.Index(fields=['name']),
            gis_models.Index(fields=['location'], name='location_idx'),
        ]

    @classmethod
    def nearby_places(cls, point, distance_km):
        """
        指定された地点から指定距離内にある場所を検索
        """
        return cls.objects.filter(
            location__distance_lte=(point, D(km=distance_km))
        ).annotate(
            distance=Distance('location', point)
        ).order_by('distance')

    @classmethod
    def search_places(cls, query, point=None, distance_km=None):
        """
        場所を名前で検索し、オプションで距離でフィルタリング
        """
        qs = cls.objects.filter(name__icontains=query)
        if point and distance_km:
            qs = qs.filter(location__distance_lte=(point, D(km=distance_km)))
            qs = qs.annotate(distance=Distance('location', point))
            qs = qs.order_by('distance')
        return qs

    @classmethod
    def places_in_bbox(cls, min_lat, max_lat, min_lon, max_lon):
        """
        指定された境界ボックス内の場所を検索
        """
        bbox = Polygon.from_bbox((min_lon, min_lat, max_lon, max_lat))
        return cls.objects.filter(location__within=bbox)

    def update_rating(self):
        """
        場所の評価を投稿の評価から更新
        """
        from .post import Posts
        avg_rating = Posts.objects.filter(place=self).aggregate(
            models.Avg('rating'))['rating__avg']
        self.rating = avg_rating
        self.save()

    @property
    def favorite_count(self):
        """
        お気に入り登録数を取得
        """
        count = self.favorites.count()
        return int(count) if count is not None else 0

    def __str__(self):
        return self.name

class Favorites(models.Model):
    """
    ユーザーのお気に入り場所を管理するモデル
    """
    # お気に入りを一意に識別するID
    id = models.AutoField(primary_key=True)
    # お気に入りを登録したユーザー
    user = models.ForeignKey(Users, on_delete=models.CASCADE)
    # お気に入りに登録された場所
    place = models.ForeignKey(
        Places, 
        on_delete=models.CASCADE, 
        related_name='favorites'
    )
    # 登録された日時
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user.name}さんのお気に入り"
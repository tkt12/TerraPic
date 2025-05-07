from django.contrib import admin
from django.contrib.gis.admin import OSMGeoAdmin
from .models.user import Users, Follows, Notifications, Reports_users
from .models.place import Places, Favorites
from .models.post import Posts, Comments, Likes, Reports_posts

@admin.register(Users)
class UsersAdmin(admin.ModelAdmin):
    list_display = ('username', 'email', 'name', 'is_staff', 'is_active')
    search_fields = ('username', 'email', 'name')
    list_filter = ('is_staff', 'is_active')

@admin.register(Follows)
class FollowsAdmin(admin.ModelAdmin):
    list_display = ('follower', 'followed', 'created_at')
    search_fields = ('follower__username', 'followed__username')
    list_filter = ('created_at',)

@admin.register(Notifications)
class NotificationsAdmin(admin.ModelAdmin):
    list_display = ('user', 'type', 'message', 'is_read', 'created_at')
    list_filter = ('type', 'is_read', 'created_at')
    search_fields = ('user__username', 'message')

@admin.register(Places)
class PlacesAdmin(OSMGeoAdmin):
    list_display = ('name', 'rating', 'favorite_count')
    search_fields = ('name',)
    list_filter = ('rating',)

@admin.register(Favorites)
class FavoritesAdmin(admin.ModelAdmin):
    list_display = ('user', 'place', 'created_at')
    search_fields = ('user__username', 'place__name')
    list_filter = ('created_at',)

@admin.register(Posts)
class PostsAdmin(admin.ModelAdmin):
    list_display = ('user', 'place', 'rating', 'like_count', 'created_at')
    search_fields = ('user__username', 'place__name', 'description')
    list_filter = ('weather', 'season', 'created_at', 'rating')
    readonly_fields = ('like_count',)

@admin.register(Comments)
class CommentsAdmin(admin.ModelAdmin):
    list_display = ('user', 'post', 'comment', 'created_at')
    search_fields = ('user__username', 'post__description', 'comment')
    list_filter = ('created_at',)

@admin.register(Likes)
class LikesAdmin(admin.ModelAdmin):
    list_display = ('user', 'post', 'created_at')
    search_fields = ('user__username', 'post__description')
    list_filter = ('created_at',)

@admin.register(Reports_users)
class ReportsUsersAdmin(admin.ModelAdmin):
    list_display = ('user', 'reported_user', 'reason', 'created_at')
    search_fields = ('user__username', 'reported_user__username', 'reason')
    list_filter = ('created_at',)

@admin.register(Reports_posts)
class ReportsPostsAdmin(admin.ModelAdmin):
    list_display = ('user', 'post', 'reason', 'created_at')
    search_fields = ('user__username', 'post__description', 'reason')
    list_filter = ('created_at',)
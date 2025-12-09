from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from .custom_jwt import CustomTokenObtainPairView
from .api import (
    # 認証関連のビュー
    login_api, signup_api, home,

    # プロフィール関連のビュー
    profile, profile_edit, user_profile, follow_toggle, profile_likes, profile_favorites, get_followers, get_following,

    # 場所関連のビュー
    NearbyPlacesView, PlaceSearchView, FavoriteView,
    FavoriteStatusView, get_top_photo, place_details,

    # 投稿関連のビュー
    CreatePostView, LikeView, LikeStatusView, delete_post, update_post,

    # ランキング関連のビュー
    places_ranking, posts_ranking,

    # 検索関連のビュー
    search, search_suggestions
)

urlpatterns = [
    # 認証関連のURL
    path('api/token/', CustomTokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('api/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('api/login/', login_api, name='login_api'),
    path('api/signup/', signup_api, name='signup_api'),
    path('api/home/', home, name='home'),
    
    # ホーム画面
    path('api/home/', home, name='home'),
    
    # 場所関連のエンドポイント
    path('api/places/', NearbyPlacesView.as_view(), name='nearby_places'),
    path('api/places/<int:place_id>/top_photo/', get_top_photo, name='top_photo'),
    path('api/places/<int:place_id>/details/', place_details, name='place_details'),
    path('api/places/<int:place_id>/favorite/', FavoriteView.as_view(), name='toggle_favorite'),
    path('api/places/<int:place_id>/favorite/status/', FavoriteStatusView.as_view(), name='favorite_status'),
    
    # 検索関連のエンドポイント
    path('api/search/', search, name='search'),
    path('api/search/suggestions/', search_suggestions, name='search_suggestions'),
    
    # 投稿関連のエンドポイント
    path('api/post/create/', CreatePostView.as_view(), name='create_post'),
    path('api/post_place_search/', PlaceSearchView.as_view(), name='search_place_post'),
    path('api/post/<int:post_id>/like/', LikeView.as_view(), name='toggle_like'),
    path('api/post/<int:post_id>/like/status/', LikeStatusView.as_view(), name='like_status'),
    path('api/post/<int:post_id>/delete/', delete_post, name='delete_post'),
    path('api/post/<int:post_id>/update/', update_post, name='update_post'),
    
    # ランキングのエンドポイント
    path('api/ranking/places', places_ranking, name='places_ranking'),
    path('api/ranking/posts', posts_ranking, name='posts_ranking'),
    
    # プロフィール関連のエンドポイント
    path('api/profile/', profile, name='profile'),
    path('api/profile/edit/', profile_edit, name='profile_edit'),
    path('api/profile/likes/', profile_likes, name='profile_likes'),
    path('api/profile/favorites/', profile_favorites, name='profile_favorites'),
    path('api/users/<str:user_id>/', user_profile, name='user_profile'),
    path('api/users/<str:user_id>/follow', follow_toggle, name='follow_toggle'),
    path('api/users/<str:user_id>/followers/', get_followers, name='get_followers'),
    path('api/users/<str:user_id>/following/', get_following, name='get_following'),
]
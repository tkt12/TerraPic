# TerraPic

<div align="center">

**位置情報ベースの写真共有SNSアプリケーション**

地図上で撮影スポットを発見し、写真を共有し、ランキングで人気の場所を見つけよう

</div>

---

## 目次

- [概要](#概要)
- [主な機能](#主な機能)
- [技術スタック](#技術スタック)
- [アーキテクチャ](#アーキテクチャ)
- [セットアップ](#セットアップ)
- [開発ガイド](#開発ガイド)
- [API仕様](#api仕様)
- [プロジェクト構成](#プロジェクト構成)
- [貢献](#貢献)

---

## 概要

TerraPicは、位置情報を活用した写真共有SNSアプリケーションです。ユーザーは地図上で撮影スポットを発見し、その場所で撮影した写真を投稿・共有できます。PostGISを活用した高度な地理空間クエリにより、近くの撮影スポットの検索や、ズームレベルに応じた詳細な写真位置の表示が可能です。

### 特徴

- **地理空間データベース**: PostGISを使用した高性能な位置情報クエリ
- **リアルタイムマップ**: Google Maps統合による動的なマーカー表示
- **多段階マーカー表示**: ズームレベルに応じて場所マーカーと詳細な写真スポットマーカーを切り替え
- **SNS機能**: いいね、お気に入り、フォロー、コメント機能
- **ランキングシステム**: 人気の場所と投稿のランキング表示
- **JWT認証**: セキュアな認証システム

---

## 主な機能

### ユーザー機能
- **認証**: メールアドレスベースのユーザー登録・ログイン（JWT認証）
- **プロフィール管理**: プロフィール画像、自己紹介、ユーザー統計の表示・編集
- **フォロー機能**: 他のユーザーをフォロー・フォロワー管理

### 地図・場所機能
- **インタラクティブマップ**: Google Maps統合、カスタムスタイル適用
- **動的マーカー表示**:
  - ズームレベル < 16: 場所の中心にマーカー表示
  - ズームレベル ≥ 16: 各投稿の正確な撮影位置にマーカー表示
- **近隣検索**: 現在の表示範囲内の撮影スポットを自動検索
- **お気に入り登録**: 気に入った場所をお気に入りに追加
- **場所詳細**: 場所の評価、投稿一覧、トップ写真の表示

### 投稿機能
- **写真投稿**:
  - 写真のアップロード
  - 撮影位置の記録（GPS情報またはマップ選択）
  - 場所の評価（1-5段階）
  - 天気・季節情報の記録
- **いいね機能**: 投稿へのいいね
- **コメント機能**: 投稿へのコメント（モデル実装済み）
- **検索**: 場所名、投稿内容による検索

### ランキング機能
- **場所ランキング**: お気に入り数でソート
- **投稿ランキング**: いいね数でソート

### ディスカバリー機能
- **ホームフィード**: フォロー中のユーザーの投稿を表示
- **検索機能**: 場所、ユーザー、投稿の統合検索

---

## 技術スタック

### バックエンド

| 技術 | バージョン | 用途 |
|------|-----------|------|
| **Python** | 3.9+ | プログラミング言語 |
| **Django** | 4.2 | Webフレームワーク |
| **Django REST Framework** | 3.14+ | REST API構築 |
| **PostgreSQL** | 14 | リレーショナルデータベース |
| **PostGIS** | - | 地理空間データベース拡張 |
| **SimpleJWT** | - | JWT認証 |
| **Docker** | - | コンテナ化 |
| **Docker Compose** | - | マルチコンテナ管理 |

#### 主要なPythonパッケージ
- `djangorestframework` - REST API
- `djangorestframework-simplejwt` - JWT認証
- `django-allauth` - ユーザー認証
- `psycopg2-binary` - PostgreSQLアダプター
- `Pillow` - 画像処理
- `django-cors-headers` - CORS設定
- `python-dotenv` - 環境変数管理

### フロントエンド

| 技術 | バージョン | 用途 |
|------|-----------|------|
| **Flutter** | 3.4+ | モバイルフレームワーク |
| **Dart** | 3.4.1+ | プログラミング言語 |

#### 主要なFlutterパッケージ
- `google_maps_flutter` (^2.5.3) - Google Maps統合
- `provider` (^6.0.1) - 状態管理
- `http` (^1.1.0) - HTTPクライアント
- `geolocator` (^13.0.1) - 位置情報取得
- `location` (^6.0.2) - 位置情報サービス
- `permission_handler` (^11.3.1) - 権限管理
- `image_picker` (^1.1.2) - 画像選択
- `shared_preferences` (^2.2.0) - ローカルストレージ
- `firebase_core` (^2.24.0) - Firebase統合
- `flutter_staggered_grid_view` (^0.7.0) - グリッドレイアウト
- `intl` (^0.19.0) - 国際化

---

## アーキテクチャ

### システムアーキテクチャ

```
┌─────────────────┐
│  Flutter App    │  ← モバイルクライアント (iOS/Android)
│  (Frontend)     │
└────────┬────────┘
         │ HTTP/REST API
         │ JWT Authentication
         ↓
┌─────────────────┐
│  Django REST    │  ← APIサーバー
│  Framework      │
└────────┬────────┘
         │ ORM
         ↓
┌─────────────────┐
│  PostgreSQL +   │  ← データベース
│  PostGIS        │
└─────────────────┘
```

### バックエンドアーキテクチャ

```
terrapic_backend/
├── terrapic_backend/
│   ├── settings.py           # Django設定
│   ├── urls.py               # ルーティング
│   └── terrapic/             # メインアプリ
│       ├── models/           # データモデル
│       │   ├── user.py       # Users, Follows, Notifications, Reports_users
│       │   ├── place.py      # Places, Favorites (PostGIS使用)
│       │   └── post.py       # Posts, Comments, Likes, Reports_posts
│       ├── api/              # APIビュー
│       │   ├── auth.py       # 認証エンドポイント
│       │   ├── place.py      # 場所エンドポイント
│       │   ├── post.py       # 投稿エンドポイント
│       │   ├── profile.py    # プロフィールエンドポイント
│       │   ├── ranking.py    # ランキングエンドポイント
│       │   └── search.py     # 検索エンドポイント
│       ├── serializers/      # DRFシリアライザー
│       ├── services/         # ビジネスロジック層
│       │   ├── place_service.py
│       │   ├── post_service.py
│       │   └── profile_service.py
│       ├── utils/            # ヘルパー関数
│       └── custom_jwt.py     # カスタムJWT実装
└── docker-compose.yml        # Docker構成
```

#### データモデル

**Users** (カスタムユーザーモデル)
- メールアドレスベースの認証
- プロフィール画像、自己紹介
- 論理削除対応

**Places** (PostGIS使用)
- 撮影場所の管理
- `PointField`による位置情報
- 評価（レーティング）
- 地理空間インデックス

**Posts**
- 写真投稿
- 場所との関連付け
- 撮影スポットの正確な位置（`photo_spot_location`）
- 評価、天気、季節情報
- いいね数のカウント

**その他のモデル**
- Follows: フォロー関係
- Favorites: お気に入り場所
- Likes: 投稿へのいいね
- Comments: 投稿へのコメント
- Notifications: 通知
- Reports_users, Reports_posts: 通報機能

### フロントエンドアーキテクチャ

```
terrapic_frontend/lib/
├── main.dart                  # アプリエントリーポイント
├── core/                      # アプリ設定
│   ├── config/
│   │   └── app_config.dart    # バックエンドURL設定
│   └── constants/
│       └── api_endpoints.dart # APIエンドポイント定義
├── features/                  # 機能ベースモジュール
│   ├── auth/                  # 認証機能
│   │   ├── screens/          # ログイン・サインアップ画面
│   │   ├── providers/        # AuthProvider (JWT管理)
│   │   └── services/         # auth_service
│   ├── home/                  # ホーム（地図）機能
│   │   ├── screens/          # GoogleMap表示
│   │   └── widgets/          # マップコントロール
│   ├── places/                # 場所機能
│   │   ├── screens/          # 場所詳細画面
│   │   ├── models/           # Placeモデル
│   │   └── widgets/          # 場所カード等
│   ├── posts/                 # 投稿機能
│   │   ├── screens/          # 投稿作成・詳細画面
│   │   ├── models/           # Postモデル
│   │   └── widgets/          # 投稿カード等
│   ├── profile/               # プロフィール機能
│   │   ├── screens/          # プロフィール表示・編集
│   │   └── widgets/          # ユーザーカード等
│   ├── ranking/               # ランキング機能
│   ├── search/                # 検索機能
│   └── main/                  # メイン画面（ナビゲーション）
└── shared/                    # 共有コンポーネント
    ├── providers/            # NavigationProvider
    ├── services/             # NavigationService
    ├── widgets/              # 共通ウィジェット
    ├── routes/               # ルーティング
    └── utils/                # ヘルパー関数
```

#### 設計パターン

- **Provider パターン**: 状態管理（AuthProvider, NavigationProvider）
- **サービス層**: ビジネスロジックの分離（auth_service, discovery_service等）
- **機能ベースアーキテクチャ**: 各機能を独立したモジュールとして管理
- **グローバルナビゲーション**: NavigationServiceによる一元管理

---

## セットアップ

### 前提条件

- Docker & Docker Compose
- Flutter SDK 3.4.1以上
- Dart SDK 3.4.1以上
- Google Maps API キー
- Google Places API キー

### 1. リポジトリのクローン

```bash
git clone <repository-url>
cd TerraPic
```

### 2. APIキーの設定

詳細な手順は [SETUP_SECRETS.md](SETUP_SECRETS.md) を参照してください。

#### バックエンド

```bash
cd terrapic_backend
cp .env.example .env
```

`.env`ファイルを編集してGoogle Places APIキーを設定:

```env
GOOGLE_PLACES_API_KEY=your-actual-api-key-here
```

#### フロントエンド（Android）

```bash
cd terrapic_frontend/android
cp gradle.properties.example gradle.properties
```

`gradle.properties`を編集:

```properties
GOOGLE_MAPS_API_KEY=your-actual-api-key-here
```

#### フロントエンド（iOS）

```bash
cd terrapic_frontend/ios/Flutter
cp Secrets.xcconfig.example Secrets.xcconfig
```

`Secrets.xcconfig`を編集:

```
GOOGLE_MAPS_API_KEY=your-actual-api-key-here
```

### 3. バックエンドのセットアップ

```bash
cd terrapic_backend

# Dockerコンテナの起動
docker-compose up -d

# マイグレーションの実行
docker-compose exec web python manage.py migrate

# スーパーユーザーの作成（オプション）
docker-compose exec web python manage.py createsuperuser
```

バックエンドは `http://localhost:8000` で起動します。

### 4. フロントエンドのセットアップ

```bash
cd terrapic_frontend

# 依存関係のインストール
flutter pub get

# アプリの実行
flutter run
```

#### バックエンドURLの設定

デフォルトでは`http://localhost:8000`に接続します。変更する場合:

```bash
# 環境変数で指定
export BACKEND_URL=http://your-backend-url:8000
flutter run
```

または `lib/core/config/app_config.dart` を編集してください。

---

## 開発ガイド

### バックエンド開発

#### 開発サーバーの起動

```bash
cd terrapic_backend
docker-compose up
```

#### ログの確認

```bash
docker-compose logs -f web
```

#### Djangoシェルの起動

```bash
docker-compose exec web python manage.py shell
```

#### 管理画面

`http://localhost:8000/admin` でDjango管理画面にアクセスできます。

#### テストの実行

```bash
docker-compose exec web python manage.py test
```

#### マイグレーションの作成

```bash
docker-compose exec web python manage.py makemigrations
docker-compose exec web python manage.py migrate
```

### フロントエンド開発

#### 開発サーバーの起動

```bash
cd terrapic_frontend
flutter run
```

#### ホットリロード

- `r` キーを押すとホットリロード
- `R` キーを押すとホットリスタート

#### コード解析

```bash
flutter analyze
```

#### ビルド

**iOS**:
```bash
flutter build ios
```

**Android**:
```bash
flutter build apk
```

#### デバッグ

Flutter DevToolsを使用:
```bash
flutter pub global activate devtools
flutter pub global run devtools
```

---

## API仕様

### 認証

すべてのAPIリクエスト（ログイン・サインアップを除く）にはJWT認証が必要です。

```
Authorization: Bearer <access_token>
```

**トークンの有効期限**:
- アクセストークン: 60分
- リフレッシュトークン: 1日

### 主要エンドポイント

#### 認証

| エンドポイント | メソッド | 説明 |
|--------------|---------|------|
| `/api/token/` | POST | JWT取得（ログイン） |
| `/api/token/refresh/` | POST | JWTリフレッシュ |
| `/api/signup/` | POST | ユーザー登録 |
| `/api/login/` | POST | ログイン |

#### 場所

| エンドポイント | メソッド | 説明 |
|--------------|---------|------|
| `/api/places/` | GET | 近くの場所を検索 |
| `/api/places/<id>/details/` | GET | 場所詳細 |
| `/api/places/<id>/top_photo/` | GET | トップ写真取得 |
| `/api/places/<id>/favorite/` | POST | お気に入り切り替え |
| `/api/places/<id>/favorite/status/` | GET | お気に入り状態 |

**近くの場所検索のクエリパラメータ**:
```
?min_lat=<float>&max_lat=<float>&min_lon=<float>&max_lon=<float>
```

#### 投稿

| エンドポイント | メソッド | 説明 |
|--------------|---------|------|
| `/api/post/create/` | POST | 投稿作成 |
| `/api/post/<id>/like/` | POST | いいね切り替え |
| `/api/post/<id>/like/status/` | GET | いいね状態 |
| `/api/post_place_search/` | GET | 投稿用場所検索 |

**投稿作成リクエスト** (multipart/form-data):
```
photo_image: File
place_data: JSON string {name, latitude, longitude}
description: string
rating: float (1-5)
weather: string
season: string
```

#### プロフィール

| エンドポイント | メソッド | 説明 |
|--------------|---------|------|
| `/api/profile/` | GET | 自分のプロフィール取得 |
| `/api/profile/edit/` | PUT | プロフィール編集 |
| `/api/profile/likes/` | GET | いいねした投稿一覧 |
| `/api/profile/favorites/` | GET | お気に入り場所一覧 |
| `/api/users/<id>/` | GET | ユーザープロフィール取得 |
| `/api/users/<id>/follow` | POST | フォロー切り替え |
| `/api/users/<id>/followers/` | GET | フォロワー一覧 |
| `/api/users/<id>/following/` | GET | フォロー中一覧 |

#### ランキング

| エンドポイント | メソッド | 説明 |
|--------------|---------|------|
| `/api/ranking/places` | GET | 場所ランキング |
| `/api/ranking/posts` | GET | 投稿ランキング |

#### 検索

| エンドポイント | メソッド | 説明 |
|--------------|---------|------|
| `/api/search/` | GET | 統合検索 |

**検索クエリパラメータ**:
```
?q=<search_term>&type=<places|posts|users>
```

### エラーレスポンス

```json
{
    "error": "エラーメッセージ"
}
```

**HTTPステータスコード**:
- `200`: 成功
- `201`: 作成成功
- `400`: リクエスト不正
- `401`: 認証エラー
- `403`: 権限エラー
- `404`: リソース未発見
- `500`: サーバーエラー

---

## プロジェクト構成

### データベース構成

**PostgreSQL + PostGIS**
- データベース名: `terrapic`
- ユーザー: `admin` (開発環境)
- ポート: `5432`

**PostGIS機能**:
- `PointField`による位置情報の格納
- 距離計算とソート
- バウンディングボックスクエリ
- 地理空間インデックスによる高速検索

### 環境変数

#### バックエンド (.env)

```env
# データベース
DB_NAME=terrapic
DB_USER=admin
DB_PASSWORD=admin

# Django
SECRET_KEY=<your-secret-key>
DEBUG=True
DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1

# CORS
CORS_ALLOW_ALL_ORIGINS=True

# API Keys
GOOGLE_PLACES_API_KEY=<your-api-key>
```

#### フロントエンド

- `BACKEND_URL`: バックエンドAPIのURL（デフォルト: `http://localhost:8000`）
- `GOOGLE_MAPS_API_KEY`: Google Maps APIキー（gradle.properties / Secrets.xcconfig）

### セキュリティ

- **認証**: JWT (SimpleJWT)
- **パスワード**: Django標準のハッシュ化
- **CORS**: 開発環境では全て許可、本番環境では制限推奨
- **APIキー管理**: `.gitignore`により秘密情報を除外

**重要**: `.env`, `gradle.properties`, `Secrets.xcconfig`は絶対にGitにコミットしないでください。

---

## 貢献

プルリクエストを歓迎します。大きな変更の場合は、まずissueを開いて変更内容を議論してください。

### 開発フロー

1. このリポジトリをフォーク
2. 機能ブランチを作成 (`git checkout -b feature/amazing-feature`)
3. 変更をコミット (`git commit -m 'Add some amazing feature'`)
4. ブランチにプッシュ (`git push origin feature/amazing-feature`)
5. プルリクエストを作成

---

## ライセンス

[ライセンス情報をここに記載]

---

## 連絡先

プロジェクトに関する質問や提案がある場合は、issueを作成してください。

---

## 謝辞

- Google Maps Platform
- Django & Django REST Framework コミュニティ
- Flutter コミュニティ
- PostGIS プロジェクト
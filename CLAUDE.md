# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TerraPic is a location-based photo sharing application with a Django REST backend and Flutter mobile frontend. Users can discover photography spots, share photos at specific locations, view rankings, and interact with other users' content.

## Architecture

### Backend (Django REST + PostGIS)
- **Framework**: Django 4.2 with Django REST Framework
- **Database**: PostgreSQL with PostGIS for geospatial queries
- **Authentication**: JWT using SimpleJWT (access token: 60min, refresh: 1 day)
- **Containerization**: Docker Compose with PostGIS database service

**Structure**:
- `terrapic_backend/terrapic_backend/terrapic/` - Main Django app
  - `models/` - User, Place (geospatial), Post models
  - `api/` - API views (auth, place, post, profile, ranking, search)
  - `serializers/` - DRF serializers
  - `services/` - Business logic layer (place_service, post_service, profile_service)
  - `utils/` - Helper functions
- Custom user model: `Users` (email-based login via Django Allauth)
- PostGIS integration for location-based queries (nearby places, distance calculations)

### Frontend (Flutter)
- **Framework**: Flutter 3.4+ (Dart SDK >=3.4.1)
- **State Management**: Provider pattern
- **Key Dependencies**: google_maps_flutter, geolocator, firebase_core, http, shared_preferences

**Structure**:
- `terrapic_frontend/lib/`
  - `features/` - Feature-based modules (auth, home, places, posts, profile, ranking, search, discovery, main)
  - `core/` - App configuration, constants, theme
  - `shared/` - Shared providers, services, widgets, models, routes, utils
- Main entry: `main.dart` with AuthWrapper handling authentication flow
- API config: `core/config/app_config.dart` (backend URL can be set via `BACKEND_URL` environment variable)

## Development Commands

### Backend

**Start development environment**:
```bash
cd terrapic_backend
docker-compose up
```

**Run migrations**:
```bash
docker-compose exec web python manage.py migrate
```

**Create superuser**:
```bash
docker-compose exec web python manage.py createsuperuser
```

**Run management commands in container**:
```bash
docker-compose exec web python manage.py <command>
```

**Access Django shell**:
```bash
docker-compose exec web python manage.py shell
```

**View logs**:
```bash
docker-compose logs -f web
```

### Frontend

**Install dependencies**:
```bash
cd terrapic_frontend
flutter pub get
```

**Run app (development)**:
```bash
flutter run
```

**Build for iOS**:
```bash
flutter build ios
```

**Build for Android**:
```bash
flutter build apk
```

**Run tests**:
```bash
flutter test
```

**Run linter**:
```bash
flutter analyze
```

## Configuration Notes

### Backend Configuration
- Database: PostGIS container accessible on `localhost:5432`
- Django server: Runs on `http://localhost:8000` in container
- Default credentials: `admin/admin` (development only)
- `DJANGO_ALLOWED_HOSTS` includes local network IPs for mobile testing
- GDAL library path is configured for ARM64 architecture
- CORS enabled for all origins in development

### Frontend Configuration
- Backend URL: Set via `BACKEND_URL` environment variable or defaults to `http://localhost:8000`
- Requires camera, location, and photo library permissions
- Locked to portrait mode
- Japanese locale (ja_JP) configured by default
- Firebase integration configured for iOS/Android

## Key API Endpoints

- `/api/token/` - JWT token obtain (login)
- `/api/token/refresh/` - JWT token refresh
- `/api/signup/` - User registration
- `/api/places/` - Nearby places (geospatial query)
- `/api/places/<id>/details/` - Place details
- `/api/places/<id>/favorite/` - Toggle favorite
- `/api/post/create/` - Create post with photo
- `/api/post/<id>/like/` - Toggle like
- `/api/ranking/places` - Top places ranking
- `/api/ranking/posts` - Top posts ranking
- `/api/search/` - Search functionality
- `/api/profile/` - User profile
- `/api/users/<id>/follow` - Toggle follow

## Architecture Patterns

### Backend
- Service layer pattern: Business logic in `services/` separate from API views
- JWT authentication with custom token view (`custom_jwt.py`)
- Geospatial queries using PostGIS with `PointField` and distance annotations
- Image uploads handled via `ImageField` stored in `media/` directory

### Frontend
- Provider pattern for state management (AuthProvider, NavigationProvider)
- Service layer for API communication (auth_service, discovery_service)
- Feature-based architecture with each feature containing screens/widgets/providers/services
- Centralized navigation via NavigationService with global navigator key
- AuthWrapper manages authentication state and routes to appropriate screens
# API Key Setup Guide

This guide explains how to set up API keys for the TerraPic application.

## Backend Setup

### 1. Create `.env` file

Copy `.env.example` to create your `.env` file:

```bash
cp .env.example .env
```

### 2. Add your API keys

Edit `.env` and add your actual API keys:

```
GOOGLE_PLACES_API_KEY=your-actual-api-key-here
```

## Frontend Setup

### Android

1. Copy the example gradle properties file:

```bash
cd terrapic_frontend/android
cp gradle.properties.example gradle.properties
```

2. Edit `gradle.properties` and add your actual Google Maps API key:

```
GOOGLE_MAPS_API_KEY=your-actual-api-key-here
```

### iOS

1. Copy the example Xcode config file:

```bash
cd terrapic_frontend/ios/Flutter
cp Secrets.xcconfig.example Secrets.xcconfig
```

2. Edit `Secrets.xcconfig` and add your actual Google Maps API key:

```
GOOGLE_MAPS_API_KEY=your-actual-api-key-here
```

## Getting API Keys

### Google Maps API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the following APIs:
   - Maps SDK for Android
   - Maps SDK for iOS
   - Places API
4. Go to "Credentials" and create an API key
5. Restrict the API key (recommended):
   - For Android: Add your app's package name and SHA-1 fingerprint
   - For iOS: Add your app's bundle identifier
   - For Places API (backend): Restrict to server IP addresses

## Security Notes

- **Never commit** the actual API keys to Git
- The `.gitignore` files are configured to exclude:
  - `.env` files
  - `gradle.properties`
  - `Secrets.xcconfig`
- Always use the `.example` files as templates
- Keep your API keys secure and rotate them if exposed

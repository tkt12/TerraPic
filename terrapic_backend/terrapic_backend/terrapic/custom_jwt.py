from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from rest_framework_simplejwt.views import TokenObtainPairView
from django.contrib.auth import authenticate
import logging

logger = logging.getLogger(__name__)

class CustomTokenObtainPairSerializer(TokenObtainPairSerializer):
    username_field = 'email'
    
    def validate(self, attrs):
        # デバッグ情報
        logger.debug(f"Received attrs: {attrs}")
        
        # 認証情報の取得
        email = attrs.get('email')
        password = attrs.get('password')
        
        # デバッグ情報
        logger.debug(f"Email: {email}")
        logger.debug(f"Password length: {len(password) if password else 0}")
        
        if email and password:
            # emailとpasswordで認証を試みる
            user = authenticate(request=self.context.get('request'), email=email, password=password)
            
            # デバッグ情報
            logger.debug(f"Authenticated user: {user}")
            
            if not user:
                msg = 'メールアドレスまたはパスワードが間違っています。'
                logger.debug(f"Authentication failed: {msg}")
                raise serializers.ValidationError(msg, code='authorization')
        else:
            msg = 'メールアドレスとパスワードを入力してください。'
            logger.debug(f"Missing credentials: {msg}")
            raise serializers.ValidationError(msg, code='authorization')

        if user is not None and user.is_active:
            # ユーザーが存在し、アクティブな場合はトークンを生成
            self.user = user
            return super().validate(attrs)
        
        return {}

class CustomTokenObtainPairView(TokenObtainPairView):
    serializer_class = CustomTokenObtainPairSerializer
    
    def post(self, request, *args, **kwargs):
        # リクエストボディをログに出力
        logger.debug(f"Request body: {request.data}")
        
        response = super().post(request, *args, **kwargs)
        
        # レスポンスの内容をログに出力
        logger.debug(f"Response status: {response.status_code}")
        logger.debug(f"Response data: {response.data}")
        
        return response
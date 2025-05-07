from rest_framework_simplejwt.tokens import RefreshToken
from django.core.exceptions import ValidationError
import re
import logging

logger = logging.getLogger(__name__)

def generate_tokens_for_user(user):
    """
    ユーザーのJWTトークンを生成する
    
    Args:
        user: Usersモデルのインスタンス
        
    Returns:
        dict: refreshトークンとaccessトークンを含む辞書
    """
    try:
        refresh = RefreshToken.for_user(user)
        return {
            'refresh': str(refresh),
            'access': str(refresh.access_token),
        }
    except Exception as e:
        logger.error(f"トークン生成中にエラー: {str(e)}")
        raise

def validate_password(password):
    """
    パスワードの強度を検証する
    
    Args:
        password: 検証するパスワード
        
    Raises:
        ValidationError: パスワードが要件を満たさない場合
    """
    if len(password) < 8:
        raise ValidationError('パスワードは8文字以上である必要があります。')
    
    if not re.search(r'[A-Z]', password):
        raise ValidationError('パスワードは少なくとも1つの大文字を含む必要があります。')
    
    if not re.search(r'[a-z]', password):
        raise ValidationError('パスワードは少なくとも1つの小文字を含む必要があります。')
    
    if not re.search(r'[0-9]', password):
        raise ValidationError('パスワードは少なくとも1つの数字を含む必要があります。')

def validate_email(email):
    """
    メールアドレスの形式を検証する
    
    Args:
        email: 検証するメールアドレス
        
    Raises:
        ValidationError: メールアドレスの形式が不正な場合
    """
    email_pattern = re.compile(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
    if not email_pattern.match(email):
        raise ValidationError('有効なメールアドレスを入力してください。')
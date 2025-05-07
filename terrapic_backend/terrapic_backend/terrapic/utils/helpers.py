from datetime import timedelta
from django.core.files.base import ContentFile
from django.db.models import Q
from django.utils import timezone

import uuid
import logging

logger = logging.getLogger(__name__)

def generate_unique_filename(original_filename):
    """
    一意のファイル名を生成する
    
    Args:
        original_filename: 元のファイル名
        
    Returns:
        str: 生成された一意のファイル名
    """
    extension = original_filename.split('.')[-1]
    return f"{uuid.uuid4()}.{extension}"

def handle_uploaded_file(file, directory='uploads/'):
    """
    アップロードされたファイルを処理する
    
    Args:
        file: アップロードされたファイルオブジェクト
        directory: 保存先ディレクトリ
        
    Returns:
        str: 保存されたファイルのパス
    """
    try:
        filename = generate_unique_filename(file.name)
        file_content = ContentFile(file.read())
        filepath = f"{directory}{filename}"
        
        return filepath, file_content
    except Exception as e:
        logger.error(f"ファイル処理中にエラー: {str(e)}")
        raise

def format_api_error(message, status_code=400):
    """
    API エラーレスポンスを整形する
    
    Args:
        message: エラーメッセージ
        status_code: HTTPステータスコード
        
    Returns:
        dict: 整形されたエラーレスポンス
    """
    return {
        'error': message,
        'status': status_code
    }

def get_client_ip(request):
    """
    クライアントのIPアドレスを取得する
    
    Args:
        request: リクエストオブジェクト
        
    Returns:
        str: クライアントのIPアドレス
    """
    x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
    if x_forwarded_for:
        ip = x_forwarded_for.split(',')[0]
    else:
        ip = request.META.get('REMOTE_ADDR')
    return ip

def get_period_filter(period, model_name):
    """
    期間に応じたクエリフィルターを生成する
    
    Args:
        period: フィルター期間（weekly/monthly/all）
        model_name: モデル名
        
    Returns:
        Q: Djangoのクエリフィルター
    """
    now = timezone.now()
    
    if period == 'weekly':
        start_date = now - timedelta(days=7)
    elif period == 'monthly':
        start_date = now - timedelta(days=30)
    else:
        return Q()

    if model_name == 'Places':
        return Q(posts__created_at__gte=start_date)
    elif model_name == 'Posts':
        return Q(created_at__gte=start_date)
    elif model_name == 'Users':
        return Q(posts__created_at__gte=start_date)
    return Q()
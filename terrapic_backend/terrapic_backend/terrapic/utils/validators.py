from django.core.exceptions import ValidationError
import magic
import logging

logger = logging.getLogger(__name__)

def validate_image_file(file):
    """
    アップロードされた画像ファイルを検証する
    
    Args:
        file: アップロードされたファイルオブジェクト
        
    Raises:
        ValidationError: ファイルが要件を満たさない場合
    """
    try:
        # ファイルサイズの検証（5MB制限）
        if file.size > 5 * 1024 * 1024:
            raise ValidationError('ファイルサイズは5MB以下にしてください。')

        # ファイルタイプの検証
        file_content = file.read()
        file_type = magic.from_buffer(file_content, mime=True)
        file.seek(0)  # ファイルポインタをリセット

        allowed_types = ['image/jpeg', 'image/png', 'image/gif']
        if file_type not in allowed_types:
            raise ValidationError('JPG、PNG、GIF形式の画像のみアップロード可能です。')

    except Exception as e:
        logger.error(f"画像検証中にエラー: {str(e)}")
        raise ValidationError('画像の検証中にエラーが発生しました。')

def validate_location_data(latitude, longitude):
    """
    位置情報データを検証する
    
    Args:
        latitude: 緯度
        longitude: 経度
        
    Raises:
        ValidationError: 位置情報が不正な場合
    """
    try:
        lat = float(latitude)
        lon = float(longitude)
        
        if not (-90 <= lat <= 90):
            raise ValidationError('緯度は-90から90の間である必要があります。')
            
        if not (-180 <= lon <= 180):
            raise ValidationError('経度は-180から180の間である必要があります。')
            
    except ValueError:
        raise ValidationError('緯度と経度は数値である必要があります。')
    except Exception as e:
        logger.error(f"位置情報検証中にエラー: {str(e)}")
        raise ValidationError('位置情報の検証中にエラーが発生しました。')

def validate_text_length(text, max_length, field_name):
    """
    テキストの長さを検証する
    
    Args:
        text: 検証するテキスト
        max_length: 最大文字数
        field_name: フィールド名（エラーメッセージ用）
        
    Raises:
        ValidationError: テキストが最大文字数を超える場合
    """
    if len(text) > max_length:
        raise ValidationError(
            f'{field_name}は{max_length}文字以内で入力してください。'
        )
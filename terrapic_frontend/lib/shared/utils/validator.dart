/// TerraPicアプリの入力検証ユーティリティ
///
/// アプリ全体で使用される入力値の検証ロジックを提供する。
/// フォームの入力値やデータの妥当性を確認する。
///
/// 主な機能:
/// - メールアドレスの検証
/// - パスワードの検証
/// - ユーザー名の検証
/// - 入力文字数の検証
///
class Validator {
  /// メールアドレスの検証
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'メールアドレスを入力してください';
    }

    final emailRegex =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value)) {
      return '有効なメールアドレスを入力してください';
    }

    return null;
  }

  /// パスワードの検証
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'パスワードを入力してください';
    }

    if (value.length < 8) {
      return 'パスワードは8文字以上で入力してください';
    }

    if (!value.contains(RegExp(r'[A-Za-z]')) ||
        !value.contains(RegExp(r'[0-9]'))) {
      return 'パスワードは英字と数字を含める必要があります';
    }

    return null;
  }

  /// パスワード確認の検証
  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return '確認用パスワードを入力してください';
    }

    if (value != password) {
      return 'パスワードが一致しません';
    }

    return null;
  }

  /// ユーザー名の検証
  static String? validateUsername(String? value) {
    if (value == null || value.isEmpty) {
      return 'ユーザー名を入力してください';
    }

    if (value.length < 3) {
      return 'ユーザー名は3文字以上で入力してください';
    }

    if (!RegExp(r'^[a-z0-9_.]+$').hasMatch(value)) {
      return 'ユーザー名は半角英数字、アンダースコア(_)、ドット(.)のみ使用できます';
    }

    return null;
  }

  /// 名前の検証
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return '名前を入力してください';
    }

    if (value.length > 30) {
      return '名前は30文字以内で入力してください';
    }

    return null;
  }

  /// 説明文の検証
  static String? validateDescription(String? value) {
    if (value != null && value.length > 1000) {
      return '説明文は1000文字以内で入力してください';
    }

    return null;
  }

  /// 評価値の検証
  static String? validateRating(double? value) {
    if (value == null) {
      return '評価を入力してください';
    }

    if (value < 1 || value > 5) {
      return '評価は1から5の間で入力してください';
    }

    return null;
  }

  /// 緯度の検証
  static String? validateLatitude(double? value) {
    if (value == null) {
      return '緯度を入力してください';
    }

    if (value < -90 || value > 90) {
      return '緯度は-90から90の間で入力してください';
    }

    return null;
  }

  /// 経度の検証
  static String? validateLongitude(double? value) {
    if (value == null) {
      return '経度を入力してください';
    }

    if (value < -180 || value > 180) {
      return '経度は-180から180の間で入力してください';
    }

    return null;
  }
}

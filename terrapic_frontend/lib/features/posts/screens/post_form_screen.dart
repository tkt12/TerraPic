/// TerraPicアプリの投稿詳細入力画面
///
/// 写真投稿の詳細情報を入力する画面。
/// 場所の選択、説明文、評価など、投稿に必要な情報を入力する。
///
/// 主な機能:
/// - 選択された写真のプレビュー表示
/// - 場所の選択（地図連携）
/// - 投稿の詳細情報入力
/// - 写真スポットの位置情報保存
/// - 投稿データのアップロード
///
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../../../core/config/app_config.dart';
import '../../../features/auth/services/auth_service.dart';
import '../../places/models/place.dart';
import '../widgets/location_picker.dart';
import '../screens/post_screen.dart';
import '../../../shared/widgets/base_layout.dart';

class PostFormScreen extends StatefulWidget {
  final File image;

  const PostFormScreen({
    super.key,
    required this.image,
  });

  @override
  PostFormScreenState createState() => PostFormScreenState();
}

class PostFormScreenState extends State<PostFormScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  // 投稿データ
  Place? _selectedPlace;
  String? _description;
  double _rating = 3.0;
  String? _weather;
  String? _season;
  bool _isLoading = false;

  // 選択肢
  final List<String> _weatherOptions = ['晴れ', '曇り', '雨', '雪', 'その他'];
  final List<String> _seasonOptions = ['春', '夏', '秋', '冬'];

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  /// 認証状態をチェック
  Future<void> _checkAuth() async {
    final token = await _authService.getAccessToken();
    if (!mounted) return;

    if (token == null) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  /// 場所選択画面に遷移
  void _navigateToLocationPicker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LocationPicker()),
    );

    if (result is Place) {
      setState(() => _selectedPlace = result);
    }
  }

  /// 投稿を送信
  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPlace == null) {
      _showError('場所を選択してください');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.refreshTokenIfNeeded();
      final token = await _authService.getAccessToken();

      if (token == null) {
        _showError('認証情報の更新に失敗しました');
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      // 場所データの準備
      final placeData = {
        'name': _selectedPlace!.name,
        'latitude': _selectedPlace!.latitude,
        'longitude': _selectedPlace!.longitude,
        'photo_spot_latitude': _selectedPlace!.photoSpotLatitude,
        'photo_spot_longitude': _selectedPlace!.photoSpotLongitude,
      };

      // マルチパートリクエストの作成
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.backendUrl}/api/post/create/'),
      );

      // ヘッダーとデータの設定
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['place_data'] = jsonEncode(placeData);
      request.fields['description'] = _description ?? '';
      request.fields['rating'] = _rating.toString();
      request.fields['weather'] = _weather ?? '';
      request.fields['season'] = _season ?? '';

      // 画像ファイルの追加
      final file = await http.MultipartFile.fromPath(
        'photo_image',
        widget.image.path,
      );
      request.files.add(file);

      // リクエストの送信
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (!mounted) return;

      if (response.statusCode == 201) {
        _showSuccess();
        Navigator.pushReplacementNamed(context, '/main');
      } else {
        throw Exception(_parseErrorResponse(responseBody));
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// エラーレスポンスをパース
  String _parseErrorResponse(String responseBody) {
    try {
      final responseData = jsonDecode(responseBody);
      if (responseData is Map<String, dynamic>) {
        if (responseData.containsKey('error')) {
          return responseData['error'];
        } else if (responseData.containsKey('detail')) {
          return responseData['detail'];
        }
      }
      return '不明なエラーが発生しました';
    } catch (e) {
      return '投稿の処理中にエラーが発生しました';
    }
  }

  /// エラーメッセージを表示
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// 成功メッセージを表示
  void _showSuccess() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('投稿が完了しました！')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ドロップダウンのスタイルを統一
    final dropdownDecoration = InputDecoration(
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.blue, width: 1.0),
        borderRadius: BorderRadius.circular(4.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.blue, width: 2.0),
        borderRadius: BorderRadius.circular(4.0),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const PostScreen(),
          ),
        );
        return false;
      },
      child: BaseLayout(
        // BaseLayoutでラップする
        showBottomBar: false, // 必要に応じてボトムバーの表示を設定
        appBar: AppBar(
          title: const Text('投稿の詳細'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context); // 一旦現在の画面を閉じる
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const PostScreen(),
                ),
              );
            },
          ),
        ),
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 画像プレビュー
                    AspectRatio(
                      aspectRatio: 1,
                      child: Image.file(
                        widget.image,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 場所選択
                    InkWell(
                      onTap: _navigateToLocationPicker,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: '場所を設定',
                          suffixIcon: Icon(Icons.arrow_forward_ios),
                        ),
                        child: Text(_selectedPlace?.name ?? '場所を選択してください'),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 説明入力
                    TextFormField(
                      decoration: const InputDecoration(labelText: '説明'),
                      maxLines: 3,
                      onChanged: (value) => _description = value,
                    ),
                    const SizedBox(height: 16),

                    // 評価入力
                    const Text('評価'),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: Colors.blue,
                        inactiveTrackColor: Colors.blue.withOpacity(0.3),
                        thumbColor: Colors.blue,
                        overlayColor: Colors.blue.withOpacity(0.4),
                        valueIndicatorColor: Colors.blue,
                      ),
                      child: Slider(
                        value: _rating,
                        min: 1,
                        max: 5,
                        divisions: 4,
                        label: _rating.toString(),
                        onChanged: (value) {
                          setState(() => _rating = value);
                        },
                      ),
                    ),

                    // 天候選択
                    Theme(
                      data: Theme.of(context).copyWith(
                        canvasColor: Colors.white, // ドロップダウンメニューの背景色
                        colorScheme: ColorScheme.light(
                          primary: Colors.blue, // フォーカス時の色（ドロップダウン選択時の色）
                        ),
                      ),
                      child: DropdownButtonFormField<String>(
                        decoration:
                            dropdownDecoration.copyWith(labelText: '天候'),
                        value: _weather,
                        dropdownColor: Colors.white, // ドロップダウンリストの背景色
                        style: const TextStyle(color: Colors.black), // テキストの色
                        icon: const Icon(Icons.arrow_drop_down,
                            color: Colors.blue), // ドロップダウンアイコンの色
                        items: _weatherOptions.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _weather = value);
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 季節選択
                    Theme(
                      data: Theme.of(context).copyWith(
                        canvasColor: Colors.white, // ドロップダウンメニューの背景色
                        colorScheme: ColorScheme.light(
                          primary: Colors.blue, // フォーカス時の色（ドロップダウン選択時の色）
                        ),
                      ),
                      child: DropdownButtonFormField<String>(
                        decoration:
                            dropdownDecoration.copyWith(labelText: '季節'),
                        value: _season,
                        dropdownColor: Colors.white, // ドロップダウンリストの背景色
                        style: const TextStyle(color: Colors.black), // テキストの色
                        icon: const Icon(Icons.arrow_drop_down,
                            color: Colors.blue), // ドロップダウンアイコンの色
                        items: _seasonOptions.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _season = value);
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 投稿ボタン
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue, // ボタンの背景色
                          foregroundColor: Colors.white, // ボタンのテキスト色
                        ),
                        onPressed: _isLoading ? null : _submitPost,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('投稿する'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

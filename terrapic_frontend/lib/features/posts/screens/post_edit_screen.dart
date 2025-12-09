/// TerraPicアプリの投稿編集画面
///
/// 既存の投稿の詳細情報を編集する画面。
/// 説明文、評価、天候、季節などの情報を更新できる。
///
/// 主な機能:
/// - 投稿写真のプレビュー表示
/// - 説明文の編集
/// - 評価の編集
/// - 天候の編集
/// - 季節の編集
/// - 更新データのアップロード
///
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:convert';

import '../../../shared/widgets/base_layout.dart';
import '../../../shared/utils/error_handler.dart';
import '../../../features/auth/services/auth_service.dart';

class PostEditScreen extends StatefulWidget {
  final Map<String, dynamic> post;

  const PostEditScreen({
    super.key,
    required this.post,
  });

  @override
  PostEditScreenState createState() => PostEditScreenState();
}

class PostEditScreenState extends State<PostEditScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  // 投稿データ
  late TextEditingController _descriptionController;
  late double _rating;
  late String _weather;
  late String _season;
  bool _isLoading = false;

  // 選択肢
  final List<String> _weatherOptions = ['晴れ', '曇り', '雨', '雪', 'その他'];
  final List<String> _seasonOptions = ['春', '夏', '秋', '冬'];

  @override
  void initState() {
    super.initState();
    // 既存のデータで初期化
    _descriptionController = TextEditingController(
      text: widget.post['description'] ?? '',
    );
    _rating = (widget.post['rating'] ?? 3.0).toDouble();

    // 天気と季節の初期化（既存の値があればそれを、なければデフォルト値）
    final existingWeather = widget.post['weather'];
    _weather = (existingWeather != null &&
                existingWeather.isNotEmpty &&
                _weatherOptions.contains(existingWeather))
        ? existingWeather
        : _weatherOptions[0];

    final existingSeason = widget.post['season'];
    _season = (existingSeason != null &&
               existingSeason.isNotEmpty &&
               _seasonOptions.contains(existingSeason))
        ? existingSeason
        : _seasonOptions[0];
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  /// 投稿を更新
  Future<void> _updatePost() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final requestBody = {
        'description': _descriptionController.text,
        'rating': _rating,
        'weather': _weather,
        'season': _season,
      };

      final response = await _authService.authenticatedRequest(
        '/api/post/${widget.post['id']}/update/',
        method: 'PATCH',
        body: jsonEncode(requestBody),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('投稿を更新しました')),
        );
        // 更新成功を通知して画面を閉じる
        Navigator.of(context).pop(true);
      } else {
        ErrorHandler.showError(context, '投稿の更新に失敗しました');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error updating post: $e');
      }
      if (!mounted) return;
      ErrorHandler.showError(context, 'エラーが発生しました');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ドロップダウンのスタイルを統一
    final dropdownDecoration = InputDecoration(
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.blue, width: 1.0),
        borderRadius: BorderRadius.circular(4.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.blue, width: 2.0),
        borderRadius: BorderRadius.circular(4.0),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );

    return BaseLayout(
      showBottomBar: false,
      appBar: AppBar(
        title: const Text('投稿を編集'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
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
                  // 画像プレビュー（編集不可）
                  if (widget.post['image_url'] != null)
                    AspectRatio(
                      aspectRatio: 1,
                      child: Image.network(
                        widget.post['image_url'],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(child: Icon(Icons.error));
                        },
                      ),
                    ),
                  const SizedBox(height: 16),

                  // 場所表示（編集不可）
                  if (widget.post['place'] != null)
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: '場所',
                        enabled: false,
                      ),
                      child: Text(widget.post['place']['name'] ?? ''),
                    ),
                  const SizedBox(height: 16),

                  // 説明入力
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: '説明'),
                    maxLines: 3,
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
                      canvasColor: Colors.white,
                      colorScheme: const ColorScheme.light(
                        primary: Colors.blue,
                      ),
                    ),
                    child: DropdownButtonFormField<String>(
                      decoration: dropdownDecoration.copyWith(
                        labelText: '天候 *',
                      ),
                      value: _weather,
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: Colors.black),
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.blue),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '天候を選択してください';
                        }
                        return null;
                      },
                      items: _weatherOptions.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _weather = value);
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 季節選択
                  Theme(
                    data: Theme.of(context).copyWith(
                      canvasColor: Colors.white,
                      colorScheme: const ColorScheme.light(
                        primary: Colors.blue,
                      ),
                    ),
                    child: DropdownButtonFormField<String>(
                      decoration: dropdownDecoration.copyWith(
                        labelText: '季節 *',
                      ),
                      value: _season,
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: Colors.black),
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.blue),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '季節を選択してください';
                        }
                        return null;
                      },
                      items: _seasonOptions.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _season = value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 更新ボタン
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isLoading ? null : _updatePost,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('更新する'),
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
    );
  }
}

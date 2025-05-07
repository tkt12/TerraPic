/// TerraPicアプリのプロフィール編集画面
///
/// ユーザーのプロフィール情報を編集する画面。
/// プロフィール画像、ユーザー名、名前、自己紹介の編集を提供する。
///
/// 主な機能:
/// - プロフィール画像の変更
/// - プロフィール情報の編集
/// - 入力のバリデーション
/// - 変更の保存
///
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../../core/config/app_config.dart';
import '../../../features/auth/services/auth_service.dart';
import '../models/profile.dart';
import '../../../shared/utils/error_handler.dart';

class ProfileEditScreen extends StatefulWidget {
  final Profile profile;

  const ProfileEditScreen({
    Key? key,
    required this.profile,
  }) : super(key: key);

  @override
  _ProfileEditScreenState createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final AuthService _authService = AuthService();

  File? _newProfileImage;
  bool _isLoading = false;
  bool _usernameChanged = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  /// コントローラーを初期化
  void _initializeControllers() {
    _usernameController.text = widget.profile.username;
    _nameController.text = widget.profile.name;
    _bioController.text = widget.profile.bio ?? '';
  }

  /// プロフィール画像を選択
  Future<void> _selectImage() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _newProfileImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      ErrorHandler.showError(context, '画像の選択に失敗しました');
    }
  }

  /// プロフィールを更新
  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // マルチパートリクエストを作成
      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('${AppConfig.backendUrl}/api/profile/edit/'),
      );

      // 認証ヘッダーを設定
      request.headers['Authorization'] =
          'Bearer ${await _authService.getAccessToken()}';

      // フィールドを設定
      request.fields['name'] = _nameController.text;
      request.fields['bio'] = _bioController.text;

      // ユーザー名が変更された場合のみ送信
      if (_usernameChanged) {
        request.fields['username'] = _usernameController.text;
      }

      // 新しい画像がある場合は追加
      if (_newProfileImage != null) {
        var file = await http.MultipartFile.fromPath(
          'profile_image',
          _newProfileImage!.path,
        );
        request.files.add(file);
      }

      // リクエストを送信
      var response = await request.send();
      var responseBody = await response.stream.bytesToString();

      if (!mounted) return;

      if (response.statusCode == 200) {
        Navigator.pop(context, true);
      } else {
        final errorMessage = _parseErrorResponse(responseBody);
        ErrorHandler.showError(context, errorMessage);
      }
    } catch (e) {
      ErrorHandler.showError(context, 'プロフィールの更新に失敗しました');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// エラーレスポンスを解析
  String _parseErrorResponse(String responseBody) {
    try {
      final data = json.decode(responseBody);
      if (data.containsKey('username')) {
        return 'このユーザー名は既に使用されています';
      }
      return data['detail'] ?? 'エラーが発生しました';
    } catch (e) {
      return 'エラーが発生しました';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('プロフィール編集'),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _updateProfile,
            ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // プロフィール画像
                  GestureDetector(
                    onTap: _selectImage,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: _newProfileImage != null
                              ? FileImage(_newProfileImage!)
                              : (widget.profile.profileImage != null
                                  ? NetworkImage(widget.profile.profileImage!)
                                  : null) as ImageProvider?,
                          child: _newProfileImage == null &&
                                  widget.profile.profileImage == null
                              ? const Icon(Icons.person, size: 50)
                              : null,
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(4.0),
                            child: Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ユーザー名
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'ユーザー名',
                      helperText: '半角英数字、アンダースコア(_)、ドット(.)のみ使用可能',
                    ),
                    onChanged: (value) {
                      setState(() {
                        _usernameChanged = value != widget.profile.username;
                      });
                    },
                    validator: Profile.validateUsername,
                  ),
                  const SizedBox(height: 16),

                  // 名前
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: '名前',
                    ),
                    validator: Profile.validateName,
                  ),
                  const SizedBox(height: 16),

                  // 自己紹介
                  TextFormField(
                    controller: _bioController,
                    decoration: const InputDecoration(
                      labelText: '自己紹介',
                      helperText: '160文字以内で入力してください',
                    ),
                    maxLines: 3,
                    validator: Profile.validateBio,
                  ),
                ],
              ),
            ),
          ),

          // ローディングオーバーレイ
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }
}

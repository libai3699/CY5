import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'api_config.dart';
import 'device_identity.dart';

class AuthSession {
  const AuthSession({
    required this.token,
    required this.username,
    required this.deviceId,
    required this.freeRemaining,
  });

  final String token;
  final String username;
  final String deviceId;
  final int freeRemaining;

  bool get trialExpired => freeRemaining <= 0;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map<String, dynamic> ? json['user'] as Map<String, dynamic> : <String, dynamic>{};
    return AuthSession(
      token: json['token']?.toString() ?? '',
      username: user['username']?.toString() ?? '',
      deviceId: user['device_id']?.toString() ?? '',
      freeRemaining: int.tryParse(user['free_remaining']?.toString() ?? '') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'token': token,
        'user': {
          'username': username,
          'device_id': deviceId,
          'free_remaining': freeRemaining,
        },
      };
}

class AuthService {
  const AuthService();

  Future<AuthSession?> loadSession() async {
    final file = await _sessionFile();
    if (!await file.exists()) return null;
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is Map<String, dynamic>) return AuthSession.fromJson(decoded);
    return null;
  }

  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    final deviceId = await const DeviceIdentity().getOrCreateDeviceId();
    return _postAuth(kAuthLoginUrl, {
      'username': username,
      'password': password,
      'device_id': deviceId,
    });
  }

  Future<AuthSession> register({
    required String username,
    required String password,
  }) async {
    final deviceId = await const DeviceIdentity().getOrCreateDeviceId();
    return _postAuth(kAuthRegisterUrl, {
      'username': username,
      'password': password,
      'device_id': deviceId,
    });
  }

  Future<void> saveSession(AuthSession session) async {
    final file = await _sessionFile();
    await file.writeAsString(jsonEncode(session.toJson()));
  }

  Future<AuthSession> _postAuth(String url, Map<String, dynamic> body) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse(url));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
      final response = await request.close();
      final raw = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) throw Exception('接口数据格式错误');
      if (decoded['code'] != 0) throw Exception(decoded['message']?.toString() ?? '请求失败');
      final data = decoded['data'];
      if (data is! Map<String, dynamic>) throw Exception('接口数据格式错误');
      final session = AuthSession.fromJson(data);
      await saveSession(session);
      return session;
    } finally {
      client.close(force: true);
    }
  }

  Future<File> _sessionFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'auth_session.json'));
  }
}

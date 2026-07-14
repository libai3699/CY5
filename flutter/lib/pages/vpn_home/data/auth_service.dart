import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'api_config.dart';
import 'device_identity.dart';

String _formatApiDateTime(String? value) {
  if (value == null || value.isEmpty) return '';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final local = parsed.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}

class AuthSession {
  const AuthSession({
    required this.token,
    required this.username,
    required this.deviceId,
    required this.freeRemaining,
    required this.inviteCode,
  });

  final String token;
  final String username;
  final String deviceId;
  final int freeRemaining;
  final String inviteCode;

  bool get trialExpired => freeRemaining <= 0;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : <String, dynamic>{};
    return AuthSession(
      token: json['token']?.toString() ?? '',
      username: user['username']?.toString() ?? '',
      deviceId: user['device_id']?.toString() ?? '',
      freeRemaining:
          int.tryParse(user['free_remaining']?.toString() ?? '') ?? 0,
      inviteCode: user['invite_code']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'token': token,
        'user': {
          'username': username,
          'device_id': deviceId,
          'free_remaining': freeRemaining,
          'invite_code': inviteCode,
        },
      };
}

class AuthService {
  const AuthService();

  Future<AuthSession?> loadSession() async {
    final file = await _sessionFile();
    if (!await file.exists()) {
      print('[AUTH] loadSession: no local session file at ${file.path}');
      return null;
    }

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) {
        final session = AuthSession.fromJson(decoded);
        print(
          '[AUTH] loadSession: loaded token=${_maskToken(session.token)} from ${file.path}',
        );
        return session;
      }
    } catch (e) {
      print('[AUTH] loadSession: invalid session file, clearing. error=$e');
      await clearSession();
    }
    return null;
  }

  Future<AuthSession> login({
    required String username,
    required String password,
    bool forceLogin = false,
  }) async {
    final deviceId = await const DeviceIdentity().getOrCreateDeviceId();
    print('[AUTH] login start username=$username device_id=$deviceId');
    return _postAuth(kAuthLoginUrl, {
      'username': username,
      'password': password,
      'device_id': deviceId,
      'force_login': forceLogin,
    });
  }

  Future<AuthSession> register({
    required String username,
    required String password,
    String inviteCode = '',
  }) async {
    final deviceId = await const DeviceIdentity().getOrCreateDeviceId();
    print('[AUTH] register start username=$username device_id=$deviceId');
    return _postAuth(kAuthRegisterUrl, {
      'username': username,
      'password': password,
      'device_id': deviceId,
      if (inviteCode.trim().isNotEmpty) 'invite_code': inviteCode.trim(),
    });
  }

  Future<void> saveSession(AuthSession session) async {
    final file = await _sessionFile();
    final parent = file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    await file.writeAsString(jsonEncode(session.toJson()), flush: true);
    print(
      '[AUTH] saveSession: saved token=${_maskToken(session.token)} to ${file.path}',
    );
  }

  Future<void> logout(String token) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client
          .postUrl(Uri.parse(kUserLogoutApiUrl))
          .timeout(const Duration(seconds: 8));
      request.headers.set('Authorization', 'Bearer $token');
      final response =
          await request.close().timeout(const Duration(seconds: 8));
      await response.drain<void>();
    } catch (e) {
      print('[AUTH] logout error: $e');
    } finally {
      client.close(force: true);
      await clearSession();
    }
  }

  Future<List<LoginDevice>> loadDevices(String token) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client
          .getUrl(Uri.parse(kUserDevicesApiUrl))
          .timeout(const Duration(seconds: 10));
      request.headers.set('Authorization', 'Bearer $token');
      final response =
          await request.close().timeout(const Duration(seconds: 10));
      final raw = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(raw);
      final data = decoded is Map<String, dynamic> ? decoded['data'] : null;
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(LoginDevice.fromJson)
            .toList();
      }
      return const [];
    } finally {
      client.close(force: true);
    }
  }

  Future<void> removeDevice(String token, int id) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client
          .deleteUrl(Uri.parse('$kUserDevicesApiUrl/$id'))
          .timeout(const Duration(seconds: 10));
      request.headers.set('Authorization', 'Bearer $token');
      final response =
          await request.close().timeout(const Duration(seconds: 10));
      await response.drain<void>();
    } finally {
      client.close(force: true);
    }
  }

  Future<void> clearSession() async {
    final file = await _sessionFile();
    if (await file.exists()) {
      print('[AUTH] clearSession: deleting ${file.path}');
      await file.delete();
    } else {
      print('[AUTH] clearSession: no session file to delete');
    }
  }

  Future<AuthSession> _postAuth(String url, Map<String, dynamic> body) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      print(
        '[AUTH] request start url=$url username=${body['username']} device_id=${body['device_id']}',
      );
      final request = await client
          .postUrl(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
      final response =
          await request.close().timeout(const Duration(seconds: 10));
      final raw = await response.transform(utf8.decoder).join();
      print('[AUTH] response status=${response.statusCode} url=$url body=$raw');
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('接口数据格式错误');
      }
      if (decoded['code'] != 0) {
        final rawData = decoded['data'];
        throw AuthException(
          code: int.tryParse(decoded['code']?.toString() ?? '') ?? -1,
          message: decoded['message']?.toString() ?? '请求失败',
          data: rawData is Map<String, dynamic>
              ? rawData
              : const <String, dynamic>{},
        );
      }
      final data = decoded['data'];
      if (data is! Map<String, dynamic>) {
        throw Exception('接口数据格式错误');
      }
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

  String _maskToken(String token) {
    if (token.length <= 12) return token;
    return '${token.substring(0, 6)}...${token.substring(token.length - 6)}';
  }
}

class AuthException implements Exception {
  const AuthException({
    required this.code,
    required this.message,
    this.data = const <String, dynamic>{},
  });

  final int code;
  final String message;
  final Map<String, dynamic> data;

  @override
  String toString() => message;
}

class LoginDevice {
  const LoginDevice({
    required this.id,
    required this.displayId,
    required this.name,
    required this.lastSeenAt,
    required this.ip,
    required this.location,
  });

  final int id;
  final String displayId;
  final String name;
  final String lastSeenAt;
  final String ip;
  final String location;

  factory LoginDevice.fromJson(Map<String, dynamic> json) {
    final brand = json['brand']?.toString() ?? '';
    final model = json['model']?.toString() ?? '';
    final name = [brand, model].where((item) => item.isNotEmpty).join(' ');
    final ipDetail = json['last_ip_detail'];
    final rawLocation = ipDetail is Map<String, dynamic>
        ? ipDetail['location']?.toString() ?? ''
        : '';
    const hiddenLocations = <String>{
      '',
      '\u672a\u77e5',
      '\u672c\u673a',
      '\u5185\u7f51',
      'GeoIP \u67e5\u8be2\u5931\u8d25',
    };
    return LoginDevice(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      displayId:
          json['display_id']?.toString() ?? json['device_id']?.toString() ?? '',
      name: name.isEmpty ? '未知设备' : name,
      lastSeenAt: _formatApiDateTime(json['last_seen_at']?.toString()),
      ip: json['last_ip']?.toString() ?? '',
      location: hiddenLocations.contains(rawLocation) ? '' : rawLocation,
    );
  }
}

import 'dart:convert';
import 'dart:io';

import '../models/app_status.dart';
import 'api_config.dart';

class RemoteAppLoader {
  const RemoteAppLoader();

  Future<AppStatus> loadStatus() async {
    final data = await _getJson(kAppStatusApiUrl);
    final body = data['data'];
    if (body is Map<String, dynamic>) return AppStatus.fromJson(body);
    throw Exception('状态接口数据格式错误');
  }

  Future<AppStatus> loadUserStatus(String token) async {
    final data = await _getJson(kUserStatusApiUrl, token: token);
    final body = data['data'];
    if (body is Map<String, dynamic>) return AppStatus.fromJson(body);
    throw Exception('状态接口数据格式错误');
  }

  Future<Map<String, String>> loadConfig() async {
    final data = await _getJson(kAppConfigApiUrl);
    final body = data['data'];
    if (body is Map<String, dynamic>) {
      return body.map((key, value) => MapEntry(key, value?.toString() ?? ''));
    }
    return const {};
  }

  Future<Map<String, dynamic>> _getJson(String url, {String? token}) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      if (token != null) {
        request.headers.set('Authorization', 'Bearer $token');
      }
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('接口请求失败：${response.statusCode}');
      }
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      throw Exception('接口数据格式错误');
    } finally {
      client.close(force: true);
    }
  }
}

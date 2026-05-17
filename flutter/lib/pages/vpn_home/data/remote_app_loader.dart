import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/app_status.dart';
import 'api_config.dart';

class RemoteAppLoader {
  const RemoteAppLoader();

  Future<AppStatus> loadStatus() async {
    final data = await _getJson(kAppStatusApiUrl);
    print('[STATUS_PUBLIC] raw: $data');
    final body = data['data'];
    if (body is Map<String, dynamic>) return AppStatus.fromJson(body);
    throw Exception('状态接口数据格式错误');
  }

  Future<AppStatus> loadUserStatus(String token) async {
    final data = await _getJson(kUserStatusApiUrl, token: token);
    print('[STATUS_USER] raw: $data');
    final body = data['data'];
    if (body is Map<String, dynamic>) return AppStatus.fromJson(body);
    throw Exception('状态接口数据格式错误');
  }

  Future<Map<String, String>> loadConfig() async {
    try {
      final data = await _getJson(kAppConfigApiUrl);
      final body = data['data'];
      if (body is Map<String, dynamic>) {
        return body.map((key, value) => MapEntry(key, value?.toString() ?? ''));
      }
      return const {};
    } catch (e) {
      print('[LOAD_CONFIG] error: $e');
      return const {};
    }
  }

  Future<Map<String, dynamic>> _getJson(String url, {String? token}) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      print('[HTTP] GET $url token=${_maskToken(token)}');
      final request = await client
          .getUrl(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (token != null) {
        request.headers.set('Authorization', 'Bearer $token');
      }
      final response =
          await request.close().timeout(const Duration(seconds: 10));
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 401) {
        print('[HTTP] 401 $url body: $body');
        throw TokenExpiredException(
          url: url,
          statusCode: response.statusCode,
          body: body,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        print('[HTTP] ${response.statusCode} $url body: $body');
        throw Exception('接口请求失败：${response.statusCode}');
      }
      print('[HTTP] ${response.statusCode} $url ok');
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      throw Exception('接口数据格式错误');
    } finally {
      client.close(force: true);
    }
  }

  String _maskToken(String? token) {
    if (token == null || token.isEmpty) return '<none>';
    if (token.length <= 12) return token;
    return '${token.substring(0, 6)}...${token.substring(token.length - 6)}';
  }
}

class TokenExpiredException implements Exception {
  const TokenExpiredException({
    this.url,
    this.statusCode,
    this.body,
  });

  final String? url;
  final int? statusCode;
  final String? body;

  @override
  String toString() =>
      'TokenExpiredException(url=$url,status=$statusCode,body=$body)';
}

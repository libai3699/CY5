import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'api_config.dart';

class DeviceIdentity {
  const DeviceIdentity();

  /// 获取或生成本地设备 ID（内部 hex，用于接口通信）
  Future<String> getOrCreateDeviceId() async {
    final file = await _deviceFile();
    if (await file.exists()) {
      final value = (await file.readAsString()).trim();
      if (value.isNotEmpty) return value;
    }
    final id = _newDeviceId();
    await file.writeAsString(id);
    return id;
  }

  /// 获取服务端分配的 7 位展示 ID（本地缓存）
  Future<String> getDisplayId() async {
    final file = await _displayIdFile();
    if (await file.exists()) {
      final value = (await file.readAsString()).trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  /// 向服务端注册设备，返回 display_id（7 位数字）
  Future<String> register() async {
    final deviceId = await getOrCreateDeviceId();
    debugPrint('[DEVICE] register device_id: $deviceId');

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client
          .postUrl(Uri.parse(kDeviceRegisterUrl))
          .timeout(const Duration(seconds: 8));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        'device_id': deviceId,
        'brand': Platform.operatingSystem,
        'model': Platform.localHostname,
        'os_version': Platform.operatingSystemVersion,
        'app_version': '1.0.0',
      }));
      final response = await request.close().timeout(const Duration(seconds: 8));
      final body = await response.transform(utf8.decoder).join();
      debugPrint('[DEVICE] register status: ${response.statusCode}, body: $body');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(body);
        final displayId = decoded?['data']?['display_id']?.toString() ?? '';
        if (displayId.isNotEmpty) {
          await _saveDisplayId(displayId);
          return displayId;
        }
      } else {
        debugPrint('[DEVICE] register failed with status ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[DEVICE] register error: $e');
    } finally {
      client.close(force: true);
    }

    // 注册失败时返回本地缓存的 display_id（如果有）
    return getDisplayId();
  }

  Future<void> _saveDisplayId(String displayId) async {
    final file = await _displayIdFile();
    await file.writeAsString(displayId);
  }

  Future<File> _deviceFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'device_id.txt'));
  }

  Future<File> _displayIdFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'display_id.txt'));
  }

  String _newDeviceId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}

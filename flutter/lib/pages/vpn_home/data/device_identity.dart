import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'api_config.dart';

class DeviceIdentity {
  const DeviceIdentity();

  Future<String> getOrCreateDeviceId() async {
    final file = await _deviceFile();
    final stableId = await _getSystemDeviceId();

    if (await file.exists()) {
      final cachedValue = (await file.readAsString()).trim();
      if (cachedValue.isNotEmpty) {
        if (Platform.isAndroid &&
            stableId != null &&
            stableId.isNotEmpty &&
            cachedValue != stableId &&
            _isLegacyAndroidBuildFingerprintId(cachedValue)) {
          debugPrint(
            '[DEVICE] Android cached build fingerprint device_id migrated to android_id: $stableId',
          );
          await file.writeAsString(stableId, flush: true);
          return stableId;
        }

        if (Platform.isWindows &&
            stableId != null &&
            stableId.isNotEmpty &&
            cachedValue != stableId) {
          debugPrint(
            '[DEVICE] Windows cached device_id mismatch, rewriting to system id: $stableId',
          );
          await file.writeAsString(stableId, flush: true);
          return stableId;
        }

        debugPrint('[DEVICE] Using cached device_id: $cachedValue');
        return cachedValue;
      }
    }

    if (stableId != null && stableId.isNotEmpty) {
      debugPrint('[DEVICE] Got system device_id: $stableId');
      await file.writeAsString(stableId, flush: true);
      return stableId;
    }

    final id = _newDeviceId();
    debugPrint('[DEVICE] Generated random device_id: $id');
    await file.writeAsString(id, flush: true);
    return id;
  }

  Future<String?> _getSystemDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidId = await _getAndroidIdFromNative();
        if (_isUsableSystemId(androidId)) {
          return 'a_$androidId';
        }

        final androidInfo = await deviceInfo.androidInfo;
        final serial = androidInfo.serialNumber.trim();
        if (_isUsableSystemId(serial)) {
          return 'a_$serial';
        }
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        final id = iosInfo.identifierForVendor?.trim();
        if (id != null && id.isNotEmpty) {
          return 'i_$id';
        }
      } else if (Platform.isWindows) {
        try {
          final regResult = await Process.run('reg', [
            'query',
            r'HKLM\SOFTWARE\Microsoft\Cryptography',
            '/v',
            'MachineGuid',
          ]);
          if (regResult.exitCode == 0) {
            final output = regResult.stdout.toString();
            final match =
                RegExp(r'MachineGuid\s+REG_SZ\s+(\S+)').firstMatch(output);
            final guid = match?.group(1)?.trim();
            if (guid != null && guid.isNotEmpty) {
              debugPrint('[DEVICE] Windows MachineGuid: $guid');
              return 'w_$guid';
            }
          }
          debugPrint(
            '[DEVICE] Windows reg query failed: exit=${regResult.exitCode}',
          );
        } catch (e) {
          debugPrint('[DEVICE] Windows MachineGuid error: $e');
        }
      }
    } catch (e) {
      debugPrint('[DEVICE] getSystemDeviceId error: $e');
    }
    return null;
  }

  Future<String?> _getAndroidIdFromNative() async {
    try {
      const channel = MethodChannel('9.9/native');
      final id = await channel.invokeMethod<String>('getAndroidId');
      return id?.trim();
    } catch (e) {
      debugPrint('[DEVICE] Android native id error: $e');
      return null;
    }
  }

  bool _isUsableSystemId(String? value) {
    final id = value?.trim();
    return id != null &&
        id.isNotEmpty &&
        id != 'unknown' &&
        id != '9774d56d682e549c' &&
        id.toLowerCase() != 'null';
  }

  bool _isLegacyAndroidBuildFingerprintId(String value) {
    if (!value.startsWith('a_')) return false;
    final raw = value.substring(2);
    return raw.contains('/') || raw.contains(':') || raw.length > 64;
  }

  Future<String> getDisplayId() async {
    final file = await _displayIdFile();
    if (await file.exists()) {
      final value = (await file.readAsString()).trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  Future<String> register() async {
    final deviceId = await getOrCreateDeviceId();
    debugPrint('[DEVICE] register device_id: $deviceId');

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
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
        'app_version': kAppVersion,
      }));
      final response =
          await request.close().timeout(const Duration(seconds: 8));
      final body = await response.transform(utf8.decoder).join();
      debugPrint(
        '[DEVICE] register status: ${response.statusCode}, body: $body',
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(body);
        final displayId = decoded?['data']?['display_id']?.toString() ?? '';
        if (displayId.isNotEmpty) {
          await _saveDisplayId(displayId);
          return displayId;
        }
      } else {
        debugPrint(
          '[DEVICE] register failed with status ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('[DEVICE] register error: $e');
    } finally {
      client.close(force: true);
    }

    return getDisplayId();
  }

  Future<void> _saveDisplayId(String displayId) async {
    final file = await _displayIdFile();
    await file.writeAsString(displayId, flush: true);
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

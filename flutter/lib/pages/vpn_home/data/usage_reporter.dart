import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/platform/vpn_native_channel.dart';
import 'api_config.dart';

class UsageReporter {
  const UsageReporter();

  static const int _maxTrafficDeltaBytes = 200 * 1024 * 1024;
  static const int _maxPersistedPendingTrafficBytes = 1024 * 1024 * 1024;

  Future<void> collectAbandonedSession() async {
    final state = await _readState();
    final startedAt = state.activeStartedAtMillis;
    if (startedAt == null || startedAt <= 0) return;

    final elapsedSeconds =
        ((DateTime.now().millisecondsSinceEpoch - startedAt) / 1000).floor();
    await _writeState(state.copyWith(
      activeStartedAtMillis: null,
      pendingSeconds:
          state.pendingSeconds + elapsedSeconds.clamp(0, 86400).toInt(),
    ));
  }

  Future<void> markConnected() async {
    final state = await _readState();
    if (state.activeStartedAtMillis != null) return;
    await _writeState(state.copyWith(
      activeStartedAtMillis: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  Future<void> collectCurrentSession() async {
    final state = await _readState();
    final startedAt = state.activeStartedAtMillis;
    final trafficDelta =
        _safeTrafficDelta(await VpnNativeChannel.pollTrafficDelta());
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsedSeconds =
        startedAt == null ? 0 : ((now - startedAt) / 1000).floor();

    await _writeState(state.copyWith(
      activeStartedAtMillis: null,
      pendingSeconds:
          state.pendingSeconds + elapsedSeconds.clamp(0, 86400).toInt(),
      pendingTrafficBytes: state.pendingTrafficBytes + trafficDelta,
    ));
  }

  Future<void> collectHeartbeatTraffic() async {
    final state = await _readState();
    final startedAt = state.activeStartedAtMillis;
    final trafficDelta =
        _safeTrafficDelta(await VpnNativeChannel.pollTrafficDelta());
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsedSeconds =
        startedAt == null ? 0 : ((now - startedAt) / 1000).floor();

    await _writeState(state.copyWith(
      activeStartedAtMillis: now,
      pendingSeconds:
          state.pendingSeconds + elapsedSeconds.clamp(0, 86400).toInt(),
      pendingTrafficBytes: state.pendingTrafficBytes + trafficDelta,
    ));
  }

  Future<void> addPendingTraffic(int trafficBytes) async {
    final safeBytes = _safeTrafficDelta(trafficBytes);
    if (safeBytes <= 0) return;
    final state = await _readState();
    await _writeState(state.copyWith(
      pendingTrafficBytes: state.pendingTrafficBytes + safeBytes,
    ));
  }

  Future<void> flush(String? token) async {
    if (token == null || token.isEmpty) return;
    final state = await _readState();
    if (state.pendingSeconds <= 0 && state.pendingTrafficBytes <= 0) return;

    final seconds = state.pendingSeconds.clamp(0, 86400).toInt();

    const maxFlushTrafficBytes = 100 * 1024 * 1024;
    var bytes = state.pendingTrafficBytes
        .clamp(0, _maxPersistedPendingTrafficBytes)
        .toInt();

    if (bytes > maxFlushTrafficBytes) {
      bytes = maxFlushTrafficBytes;
    }

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client
          .postUrl(Uri.parse(kUserHeartbeatApiUrl))
          .timeout(const Duration(seconds: 10));
      request.headers.contentType = ContentType.json;
      request.headers.set('Authorization', 'Bearer $token');
      request.write(jsonEncode({
        'seconds': seconds,
        'traffic_bytes': bytes,
      }));
      final response =
          await request.close().timeout(const Duration(seconds: 10));
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 10));
      final ok = response.statusCode >= 200 &&
          response.statusCode < 300 &&
          _isSuccessBody(body);
      if (!ok) {
        return;
      }

      await _writeState(const _UsageState(
        activeStartedAtMillis: null,
        pendingSeconds: 0,
        pendingTrafficBytes: 0,
      ));
    } catch (_) {
    } finally {
      client.close(force: true);
    }
  }

  bool _isSuccessBody(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> &&
          (decoded['code'] == 0 || decoded['code'] == 200);
    } catch (_) {
      return false;
    }
  }

  int _safeTrafficDelta(int bytes) {
    if (bytes <= 0) return 0;
    if (bytes > _maxTrafficDeltaBytes) {
      return 0;
    }
    return bytes;
  }

  _UsageState _sanitizeState(_UsageState state) {
    if (state.pendingTrafficBytes > _maxPersistedPendingTrafficBytes) {
      return state.copyWith(pendingTrafficBytes: 0);
    }
    return state;
  }

  Future<_UsageState> _readState() async {
    final file = await _stateFile();
    if (!await file.exists()) return const _UsageState();
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) {
        return _sanitizeState(_UsageState.fromJson(decoded));
      }
    } catch (_) {}
    return const _UsageState();
  }

  Future<void> _writeState(_UsageState state) async {
    final file = await _stateFile();
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsString(jsonEncode(state.toJson()), flush: true);
  }

  Future<File> _stateFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'usage_pending.json'));
  }
}

class _UsageState {
  const _UsageState({
    this.activeStartedAtMillis,
    this.pendingSeconds = 0,
    this.pendingTrafficBytes = 0,
  });

  final int? activeStartedAtMillis;
  final int pendingSeconds;
  final int pendingTrafficBytes;

  factory _UsageState.fromJson(Map<String, dynamic> json) {
    return _UsageState(
      activeStartedAtMillis:
          int.tryParse(json['active_started_at_millis']?.toString() ?? ''),
      pendingSeconds:
          int.tryParse(json['pending_seconds']?.toString() ?? '') ?? 0,
      pendingTrafficBytes:
          int.tryParse(json['pending_traffic_bytes']?.toString() ?? '') ?? 0,
    );
  }

  _UsageState copyWith({
    Object? activeStartedAtMillis = _sentinel,
    int? pendingSeconds,
    int? pendingTrafficBytes,
  }) {
    return _UsageState(
      activeStartedAtMillis: identical(activeStartedAtMillis, _sentinel)
          ? this.activeStartedAtMillis
          : activeStartedAtMillis as int?,
      pendingSeconds: pendingSeconds ?? this.pendingSeconds,
      pendingTrafficBytes: pendingTrafficBytes ?? this.pendingTrafficBytes,
    );
  }

  Map<String, dynamic> toJson() => {
        'active_started_at_millis': activeStartedAtMillis,
        'pending_seconds': pendingSeconds,
        'pending_traffic_bytes': pendingTrafficBytes,
      };
}

const Object _sentinel = Object();

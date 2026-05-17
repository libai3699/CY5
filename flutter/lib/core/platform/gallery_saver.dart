import 'dart:io' show HttpClient, Platform;
import 'dart:typed_data';

import 'package:flutter/services.dart';

class GallerySaveResult {
  const GallerySaveResult({
    required this.success,
    required this.message,
    this.permissionDenied = false,
  });

  final bool success;
  final String message;
  final bool permissionDenied;
}

class GallerySaver {
  GallerySaver._();

  static const MethodChannel _channel = MethodChannel('9.9/native');

  static Future<GallerySaveResult> saveQrCodeFromUrl(String imageUrl) async {
    if (!Platform.isAndroid) {
      return const GallerySaveResult(
        success: false,
        message: '当前设备暂不支持保存到系统相册',
      );
    }

    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(imageUrl));
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('图片下载失败');
      }

      final chunks = await response.expand((chunk) => chunk).toList();
      final bytes = Uint8List.fromList(chunks);
      final fileName =
          'payment_qr_${DateTime.now().millisecondsSinceEpoch}.png';
      final rawResult = await _channel.invokeMapMethod<String, dynamic>(
        'saveImageToGallery',
        <String, dynamic>{
          'bytes': bytes,
          'fileName': fileName,
        },
      );

      final result = rawResult ?? const <String, dynamic>{};
      return GallerySaveResult(
        success: result['success'] == true,
        message: (result['message'] as String?) ?? '保存完成',
        permissionDenied: result['permissionDenied'] == true,
      );
    } on PlatformException catch (error) {
      return GallerySaveResult(
        success: false,
        message: error.message ?? '保存失败',
      );
    } catch (error) {
      return GallerySaveResult(
        success: false,
        message: '保存失败：$error',
      );
    } finally {
      client.close(force: true);
    }
  }
}

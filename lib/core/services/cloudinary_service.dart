import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/error_mapper.dart';
import '../errors/failure.dart';
import '../result/result.dart';

/// Uploads images to Cloudinary over its unsigned-upload REST API.
///
/// Cloudinary hosts the pictures so a photo cannot blow the free Firebase
/// Storage quota, and transformation (resizing, format negotiation) happens
/// on their CDN instead of in the app. The upload target is an *unsigned*
/// preset created in the Cloudinary console (Settings → Upload → Upload
/// presets, signing mode "Unsigned", folder `flameup`): the client never
/// holds the API secret, and the preset is the only thing that can write
/// into that folder. Configure per profile in the launch flags:
///
///     --dart-define=CLOUDINARY_CLOUD_NAME=your-cloud
///     --dart-define=CLOUDINARY_UPLOAD_PRESET=your-unsigned-preset
///
/// When either is absent the service reports [cloudinaryNotConfigured]
/// instead of attempting a doomed network call — a build without the flags
/// stays launchable, and the failure is a config error, not a crash.
class CloudinaryService {
  CloudinaryService({
    this.cloudName = const String.fromEnvironment('CLOUDINARY_CLOUD_NAME'),
    this.uploadPreset = const String.fromEnvironment(
      'CLOUDINARY_UPLOAD_PRESET',
    ),
    this.endpoint = 'https://api.cloudinary.com/v1_1',
  });

  final String cloudName;
  final String uploadPreset;

  /// Overridable for tests; the real endpoint in production.
  final String endpoint;

  bool get isConfigured => cloudName.isNotEmpty && uploadPreset.isNotEmpty;

  /// Upload [file] into the preset's folder, returning the delivery URL.
  ///
  /// Images only: the family-recipe video path stays on Firebase Storage,
  /// which already handles its content types and rules.
  Future<Result<String>> uploadImage({
    required File file,
    required String uid,
  }) async {
    if (!isConfigured) {
      return const Err(
        ValidationFailure(
          messageKey: 'cloudinaryNotConfigured',
          field: 'media',
        ),
      );
    }

    return ErrorMapper.guard(() async {
      final uri = Uri.parse('$endpoint/$cloudName/image/upload');
      final request = MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..fields['folder'] = 'flameup'
        ..fields['tags'] = 'flameup,user:$uid'
        ..files.add(
          await MultipartFile.fromPath('file', file.path),
        );

      final response = await request.send().timeout(
            const Duration(seconds: 60),
          );
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        throw const FormatException('cloudinary_upload_failed');
      }
      final secureUrl = (jsonDecode(body) as Map)['secure_url'];
      if (secureUrl is! String || secureUrl.isEmpty) {
        throw const FormatException('cloudinary_upload_failed');
      }
      return secureUrl;
    });
  }
}

/// The part of `package:http`'s multipart surface used here, inlined so the
/// service needs no new dependency.
class MultipartRequest {
  MultipartRequest(this.method, this.uri);

  final String method;
  final Uri uri;
  final Map<String, String> fields = {};
  final List<MultipartFile> files = [];

  Future<HttpClientResponse> send() async {
    final boundary = 'flameup${DateTime.now().microsecondsSinceEpoch}';
    final buffer = BytesBuilder();

    void addPart(String name, String value) {
      buffer.add(
        utf8.encode(
          '--$boundary\r\n'
          'Content-Disposition: form-data; name="$name"\r\n\r\n'
          '$value\r\n',
        ),
      );
    }

    fields.forEach(addPart);
    for (final file in files) {
      final bytes = await file.readAsBytes();
      buffer.add(
        utf8.encode(
          '--$boundary\r\n'
          'Content-Disposition: form-data; name="${file.field}"; '
          'filename="${file.filename}"\r\n'
          'Content-Type: ${file.contentType}\r\n\r\n',
        ),
      );
      buffer.add(bytes);
      buffer.add(utf8.encode('\r\n'));
    }
    buffer.add(utf8.encode('--$boundary--\r\n'));

    final client = HttpClient();
    try {
      final request = await client.openUrl(method, uri)
        ..headers.set(
          HttpHeaders.contentTypeHeader,
          'multipart/form-data; boundary=$boundary',
        )
        ..headers.contentLength = buffer.length;
      request.add(buffer.takeBytes());
      return await request.close();
    } catch (_) {
      client.close(force: true);
      rethrow;
    }
  }
}

class MultipartFile {
  MultipartFile._(this.field, this.filename, this.contentType, this._read);

  static Future<MultipartFile> fromPath(String field, String path) async {
    final extension = path.split('.').last.toLowerCase();
    final contentType = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'heic' => 'image/heic',
      _ => 'application/octet-stream',
    };
    return MultipartFile._(field, path.split('/').last, contentType, () async {
      final file = File(path);
      return file.readAsBytes();
    });
  }

  final String field;
  final String filename;
  final String contentType;
  final Future<Uint8List> Function() _read;

  Future<Uint8List> readAsBytes() => _read();
}

final cloudinaryServiceProvider =
    Provider<CloudinaryService>((ref) => CloudinaryService());

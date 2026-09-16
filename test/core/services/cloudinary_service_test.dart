import 'dart:convert';
import 'dart:io';

import 'package:flameup/core/errors/failure.dart';
import 'package:flameup/core/result/result.dart';
import 'package:flameup/core/services/cloudinary_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CloudinaryService', () {
    test('without dart-define config it fails fast, with no network call',
        () async {
      final service = CloudinaryService(
        cloudName: '',
        uploadPreset: '',
        endpoint: 'https://127.0.0.1:1', // would fail instantly if contacted
      );
      expect(service.isConfigured, isFalse);

      final result = await service.uploadImage(
        file: File('/tmp/should-never-be-read.jpg'),
        uid: 'u1',
      );

      expect(result, isA<Err<String>>());
      final err = result as Err<String>;
      expect(err.failure, isA<ValidationFailure>());
      expect(
        (err.failure as ValidationFailure).messageKey,
        'cloudinaryNotConfigured',
      );
    });

    test('configured service posts multipart and returns secure_url', () async {
      late HttpRequest captured;
      late String capturedBody;

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final sub = server.listen((req) async {
        captured = req;
        // The multipart body carries binary image bytes — decode byte-safe.
        capturedBody = latin1.decode(
          await req.fold(<int>[], (a, b) => a..addAll(b)),
          allowInvalid: true,
        );
        req.response.headers.contentType = ContentType.json;
        req.response.write(
          jsonEncode({
            'secure_url':
                'https://res.cloudinary.com/demo/image/upload/v1/flameup/shiro.jpg',
          }),
        );
        await req.response.close();
      });

      final tmp = File(
        '${Directory.systemTemp.createTempSync('cloudinary-test').path}/dish.jpg',
      )..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);

      final service = CloudinaryService(
        cloudName: 'demo-cloud',
        uploadPreset: 'unsigned-preset',
        endpoint: 'http://${server.address.host}:${server.port}',
      );
      expect(service.isConfigured, isTrue);

      final result = await service.uploadImage(file: tmp, uid: 'cook-1');

      expect(result, isA<Ok<String>>());
      expect(
        (result as Ok<String>).value,
        'https://res.cloudinary.com/demo/image/upload/v1/flameup/shiro.jpg',
      );

      // The request went to the unsigned image-upload endpoint and carried
      // the preset, folder, and user tag — Cloudinary's only auth.
      expect(captured.uri.path, '/demo-cloud/image/upload');
      expect(captured.method, 'POST');
      expect(capturedBody, contains('name="upload_preset"'));
      expect(capturedBody, contains('unsigned-preset'));
      expect(capturedBody, contains('name="folder"'));
      expect(capturedBody, contains('flameup'));
      expect(capturedBody, contains('user:cook-1'));
      expect(capturedBody, contains('filename="dish.jpg"'));

      await sub.cancel();
      await server.close(force: true);
      tmp.parent.deleteSync(recursive: true);
    });

    test('a non-200 from Cloudinary maps to a failure, not a crash', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final sub = server.listen((req) async {
        await req.drain<void>();
        req.response.statusCode = HttpStatus.badRequest;
        req.response.write(
          jsonEncode({
            'error': {'message': 'bad preset'},
          }),
        );
        await req.response.close();
      });

      final tmp = File(
        '${Directory.systemTemp.createTempSync('cloudinary-test').path}/x.jpg',
      )..writeAsBytesSync([0xFF, 0xD8]);

      final service = CloudinaryService(
        cloudName: 'demo-cloud',
        uploadPreset: 'unsigned-preset',
        endpoint: 'http://${server.address.host}:${server.port}',
      );

      final result = await service.uploadImage(file: tmp, uid: 'u1');
      expect(result, isA<Err<String>>());

      await sub.cancel();
      await server.close(force: true);
      tmp.parent.deleteSync(recursive: true);
    });
  });
}

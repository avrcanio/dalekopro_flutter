import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dalekopro_farma_flutter/core/network/api_client.dart';
import 'package:dalekopro_farma_flutter/core/storage/token_storage.dart';
import 'package:dalekopro_farma_flutter/features/upload/data/upload_repository.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(setupMockSecureStorage);
  tearDown(clearMockSecureStorage);

  Future<File> tempImage() async {
    final file = File('${Directory.systemTemp.path}/upload_test.jpg');
    await file.writeAsBytes(List<int>.filled(32, 1));
    return file;
  }

  test('upload repository success', () async {
    final image = await tempImage();
    final client = ApiClient(tokenStorage: const TokenStorage());

    client.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: {'status': 'OK', 'slika_id': 100},
            ),
          );
        },
      ),
    );

    final repo = UploadRepository(client: client);
    final result = await repo.uploadCattlePhoto(
      zivotniBroj: 'HR123',
      image: image,
      datum: '2026-03-09 10:00:00',
    );

    expect(result.status, 'OK');
    expect(result.slikaId, 100);
  });

  test('upload repository maps 400 validation', () async {
    final image = await tempImage();
    final client = ApiClient(tokenStorage: const TokenStorage());

    client.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              response: Response(
                requestOptions: options,
                statusCode: 400,
                data: {'error': 'bad date'},
              ),
              type: DioExceptionType.badResponse,
            ),
          );
        },
      ),
    );

    final repo = UploadRepository(client: client);

    await expectLater(
      () => repo.uploadCattlePhoto(zivotniBroj: 'HR123', image: image),
      throwsA(isA<Exception>()),
    );
  });

  test('upload repository maps 401', () async {
    final image = await tempImage();
    final client = ApiClient(tokenStorage: const TokenStorage());

    client.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              response: Response(requestOptions: options, statusCode: 401),
              type: DioExceptionType.badResponse,
            ),
          );
        },
      ),
    );

    final repo = UploadRepository(client: client);

    await expectLater(
      () => repo.uploadCattlePhoto(zivotniBroj: 'HR123', image: image),
      throwsA(isA<Exception>()),
    );
  });

  test('upload repository maps 404', () async {
    final image = await tempImage();
    final client = ApiClient(tokenStorage: const TokenStorage());

    client.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              response: Response(requestOptions: options, statusCode: 404),
              type: DioExceptionType.badResponse,
            ),
          );
        },
      ),
    );

    final repo = UploadRepository(client: client);

    await expectLater(
      () => repo.uploadCattlePhoto(zivotniBroj: 'HR404', image: image),
      throwsA(isA<Exception>()),
    );
  });

  test('upload repository maps 5xx', () async {
    final image = await tempImage();
    final client = ApiClient(tokenStorage: const TokenStorage());

    client.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              response: Response(requestOptions: options, statusCode: 503),
              type: DioExceptionType.badResponse,
            ),
          );
        },
      ),
    );

    final repo = UploadRepository(client: client);

    await expectLater(
      () => repo.uploadCattlePhoto(zivotniBroj: 'HR123', image: image),
      throwsA(isA<Exception>()),
    );
  });
}

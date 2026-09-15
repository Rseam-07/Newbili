import 'dart:typed_data';

import 'package:PiliPlus/http/retry_interceptor.dart';
import 'package:PiliPlus/models_new/danmaku/post.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final method in ['POST', 'PUT', 'PATCH', 'DELETE']) {
    for (final type in [
      DioExceptionType.connectionError,
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.unknown,
    ]) {
      test('$method is never replayed after $type', () async {
        final adapter = _UnreliableAdapter(type);
        final dio = Dio()..httpClientAdapter = adapter;
        addTearDown(() => dio.close(force: true));
        dio.interceptors.add(RetryInterceptor(dio, 3, 0));

        await expectLater(
          dio.request<void>(
            'https://example.invalid/publish',
            options: Options(method: method),
          ),
          throwsA(isA<DioException>()),
        );
        expect(adapter.calls, 1);
      });
    }
  }

  for (final method in ['GET', 'HEAD', 'OPTIONS']) {
    test(
      '$method still recovers from a transient connection failure',
      () async {
        final adapter = _UnreliableAdapter(
          DioExceptionType.connectionError,
          succeedAfter: 1,
        );
        final dio = Dio()..httpClientAdapter = adapter;
        addTearDown(() => dio.close(force: true));
        dio.interceptors.add(RetryInterceptor(dio, 2, 0));
        final response = await dio.request<String>(
          'https://example.invalid/videos',
          options: Options(method: method),
        );
        expect(response.statusCode, 200);
        expect(adapter.calls, 2);
      },
    );
  }

  test('read retries remain bounded', () async {
    final adapter = _UnreliableAdapter(DioExceptionType.connectionError);
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));
    dio.interceptors.add(RetryInterceptor(dio, 2, 0));
    await expectLater(
      dio.get<void>('https://example.invalid/videos'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.calls, 3);
  });

  test('optional danmaku IDs tolerate number, string and missing data', () {
    expect(DanmakuPost.fromJson({'dmid': 123}).dmid, 123);
    expect(DanmakuPost.fromJson({'dmid': '123'}).dmid, 123);
    expect(DanmakuPost.fromJson({}).dmid, isNull);
    expect(DanmakuPost.fromJson({'dmid': 'not-an-id'}).dmid, isNull);
  });
}

class _UnreliableAdapter implements HttpClientAdapter {
  _UnreliableAdapter(this.type, {this.succeedAfter});
  final DioExceptionType type;
  final int? succeedAfter;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    if (succeedAfter != null && calls > succeedAfter!) {
      return ResponseBody.fromString('ok', 200);
    }
    throw DioException(requestOptions: options, type: type);
  }

  @override
  void close({bool force = false}) {}
}

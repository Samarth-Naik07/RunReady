import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:run_ready/core/errors/app_error.dart';

DioException dio(DioExceptionType type, {int? status}) {
  final options = RequestOptions(path: '/forecast');
  return DioException(
    requestOptions: options,
    type: type,
    response: status == null
        ? null
        : Response(requestOptions: options, statusCode: status),
  );
}

void main() {
  group('AppError.fromDio', () {
    test('timeouts map to TimeoutError', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.transformTimeout,
      ]) {
        expect(
          AppError.fromDio(dio(type)),
          isA<TimeoutError>(),
          reason: '$type',
        );
      }
    });

    test('connection failures map to NetworkError', () {
      expect(
        AppError.fromDio(dio(DioExceptionType.connectionError)),
        isA<NetworkError>(),
      );
      expect(
        AppError.fromDio(dio(DioExceptionType.badCertificate)),
        isA<NetworkError>(),
      );
    });

    test('HTTP error responses map to ServerError with the status code', () {
      final error = AppError.fromDio(
        dio(DioExceptionType.badResponse, status: 503),
      );

      expect(error, isA<ServerError>());
      expect((error as ServerError).statusCode, 503);
    });

    test('unknown Dio failures map to UnknownError', () {
      expect(
        AppError.fromDio(dio(DioExceptionType.unknown)),
        isA<UnknownError>(),
      );
    });
  });

  group('AppError.from', () {
    test('malformed data maps to InvalidDataError', () {
      expect(
        AppError.from(const FormatException('bad json')),
        isA<InvalidDataError>(),
      );
      // What a failed cast like `json['hourly'] as Map` throws.
      final Object value = 'not a map';
      Object? typeError;
      try {
        value as Map<String, dynamic>;
      } on TypeError catch (e) {
        typeError = e;
      }
      expect(AppError.from(typeError!), isA<InvalidDataError>());
    });

    test('anything unexpected maps to UnknownError', () {
      expect(AppError.from(StateError('boom')), isA<UnknownError>());
      expect(AppError.from(Exception('boom')), isA<UnknownError>());
    });

    test('an AppError passes through unchanged', () {
      const error = TimeoutError();
      expect(AppError.from(error), same(error));
    });

    test('keeps the original error as the cause', () {
      final original = dio(DioExceptionType.connectionError);
      expect(AppError.from(original).cause, same(original));
    });
  });

  test('user messages are friendly and never include raw error text', () {
    final raw = dio(DioExceptionType.connectionError);
    final messages = {
      const NetworkError():
          "You're offline. Check your connection and try again.",
      const TimeoutError(): 'The weather request took too long. Try again.',
      const ServerError(): 'The weather service is temporarily unavailable.',
      const InvalidDataError(): "We couldn't read the weather data. Try again.",
      const UnknownError(): 'Something went wrong. Please try again.',
    };

    messages.forEach((error, message) => expect(error.userMessage, message));
    expect(AppError.from(raw).userMessage, isNot(contains('DioException')));
  });
}

import 'package:dio/dio.dart';

/// A failure the app understands and can explain to the user.
///
/// Low-level errors (Dio, JSON parsing, ...) are converted into one of these
/// by the repository, so the UI never sees or shows raw exception text. The
/// original error is kept in [cause] for debugging only.
sealed class AppError implements Exception {
  const AppError([this.cause]);

  /// The low-level error this came from. Never shown to the user.
  final Object? cause;

  /// A short, friendly explanation for the UI.
  String get userMessage;

  /// Maps a Dio failure to an [AppError].
  ///
  /// Cancellation is not a failure, so callers should handle
  /// [DioExceptionType.cancel] themselves before calling this.
  static AppError fromDio(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.transformTimeout => TimeoutError(error),
      DioExceptionType.connectionError ||
      DioExceptionType.badCertificate => NetworkError(error),
      DioExceptionType.badResponse => ServerError(
        error,
        error.response?.statusCode,
      ),
      DioExceptionType.cancel ||
      DioExceptionType.unknown => UnknownError(error),
    };
  }

  /// Maps any error to an [AppError]. [AppError]s pass through unchanged.
  static AppError from(Object error) {
    return switch (error) {
      AppError() => error,
      DioException() => fromDio(error),
      // Thrown when a response doesn't have the expected shape or values.
      FormatException() || TypeError() => InvalidDataError(error),
      _ => UnknownError(error),
    };
  }

  @override
  String toString() => '$runtimeType($cause)';
}

/// No connection, or the server couldn't be reached.
final class NetworkError extends AppError {
  const NetworkError([super.cause]);

  @override
  String get userMessage =>
      "You're offline. Check your connection and try again.";
}

/// The request took too long.
final class TimeoutError extends AppError {
  const TimeoutError([super.cause]);

  @override
  String get userMessage => 'The weather request took too long. Try again.';
}

/// The weather service answered with an error, e.g. HTTP 500 or 503.
final class ServerError extends AppError {
  const ServerError([super.cause, this.statusCode]);

  /// The HTTP status code, when there was one.
  final int? statusCode;

  @override
  String get userMessage => 'The weather service is temporarily unavailable.';
}

/// The response arrived but couldn't be read as weather data.
final class InvalidDataError extends AppError {
  const InvalidDataError([super.cause]);

  @override
  String get userMessage => "We couldn't read the weather data. Try again.";
}

/// Anything else.
final class UnknownError extends AppError {
  const UnknownError([super.cause]);

  @override
  String get userMessage => 'Something went wrong. Please try again.';
}

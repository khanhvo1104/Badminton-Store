import 'package:base_project/core/errors/app_exception.dart';

/// Immutable result type for domain and data layer operations.
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;

  bool get isFailure => this is Failure<T>;

  R when<R>({
    required R Function(T data) success,
    required R Function(AppException error) failure,
  }) {
    return switch (this) {
      Success(:final data) => success(data),
      Failure(:final error) => failure(error),
    };
  }

  Result<R> map<R>(R Function(T data) transform) {
    return switch (this) {
      Success(:final data) => Success(transform(data)),
      Failure(:final error) => Failure(error),
    };
  }
}

final class Success<T> extends Result<T> {
  const Success(this.data);

  final T data;
}

final class Failure<T> extends Result<T> {
  const Failure(this.error);

  final AppException error;
}

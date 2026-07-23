import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Result', () {
    test('Success supports pattern matching', () {
      const Result<int> result = Success(42);

      final value = switch (result) {
        Success(data: final data) => data,
        Failure() => -1,
      };

      expect(value, 42);
      expect(result.isSuccess, isTrue);
    });

    test('Failure supports pattern matching', () {
      const Result<int> result = Failure(NetworkException('offline'));

      final message = switch (result) {
        Success() => 'ok',
        Failure(error: final error) => error.message,
      };

      expect(message, 'offline');
      expect(result.isFailure, isTrue);
    });

    test('map transforms success values', () {
      const Result<int> result = Success(2);
      final mapped = result.map((value) => value * 3);
      expect(mapped, isA<Success<int>>());
      expect((mapped as Success<int>).data, 6);
    });

    test('when covers both branches', () {
      const Result<String> success = Success('ok');
      const Result<String> failure = Failure(UnknownException('boom'));

      expect(
        success.when(success: (data) => data, failure: (_) => 'fail'),
        'ok',
      );
      expect(
        failure.when(success: (_) => 'ok', failure: (error) => error.message),
        'boom',
      );
    });
  });
}

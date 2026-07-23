import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/authentication/domain/entities/user.dart';
import 'package:base_project/features/authentication/domain/repositories/auth_repository.dart';
import 'package:base_project/features/authentication/domain/use_cases/login_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository repository;

  setUp(() {
    repository = _MockAuthRepository();
  });

  group('LoginUseCase', () {
    test('returns validation failure for invalid input', () async {
      final useCase = LoginUseCase(repository);
      final result = await useCase(email: 'bad', password: 'short');

      expect(result, isA<Failure<User>>());
      final error = (result as Failure<User>).error;
      expect(error, isA<ValidationException>());
      verifyNever(
        () => repository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      );
    });

    test('delegates to repository when valid', () async {
      const user = User(
        id: '1',
        email: 'demo@example.com',
        displayName: 'Demo',
      );
      when(
        () => repository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => const Success(user));

      final useCase = LoginUseCase(repository);
      final result = await useCase(
        email: 'demo@example.com',
        password: 'Password123',
      );

      expect(result, isA<Success<User>>());
      verify(
        () => repository.login(
          email: 'demo@example.com',
          password: 'Password123',
        ),
      ).called(1);
    });
  });
}

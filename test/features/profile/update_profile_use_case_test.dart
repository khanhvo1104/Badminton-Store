import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/authentication/domain/entities/user.dart';
import 'package:base_project/features/profile/domain/repositories/profile_repository.dart';
import 'package:base_project/features/profile/domain/use_cases/update_profile_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  late _MockProfileRepository repository;
  late UpdateProfileUseCase useCase;

  setUp(() {
    repository = _MockProfileRepository();
    useCase = UpdateProfileUseCase(repository);
  });

  test('rejects invalid display name', () async {
    final result = await useCase('A');
    expect(result, isA<Failure<User>>());
    expect((result as Failure<User>).error, isA<ValidationException>());
    verifyNever(() => repository.updateDisplayName(any()));
  });

  test('updates valid display name', () async {
    const user = User(
      id: '1',
      email: 'demo@example.com',
      displayName: 'Updated',
    );
    when(
      () => repository.updateDisplayName(any()),
    ).thenAnswer((_) async => const Success(user));

    final result = await useCase('Updated');
    expect(result, isA<Success<User>>());
    verify(() => repository.updateDisplayName('Updated')).called(1);
  });
}

import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/authentication/di/auth_providers.dart';
import 'package:base_project/features/authentication/domain/repositories/auth_repository.dart';
import 'package:base_project/shared/session/auth_session_provider.dart';
import 'package:base_project/shared/session/auth_session_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../helpers/test_container.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  test('restore session failure surfaces AuthSessionError', () async {
    final repository = _MockAuthRepository();
    when(
      () => repository.restoreSession(),
    ).thenAnswer((_) async => const Failure(CacheException('corrupt session')));
    when(
      () => repository.logout(),
    ).thenAnswer((_) async => const Success(null));

    final container = await createTestContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final sub = container.listen(
      authSessionProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);

    await container.read(authSessionProvider.notifier).restoreSession();

    final state = container.read(authSessionProvider);
    expect(state, isA<AuthSessionError>());
    expect((state as AuthSessionError).message, 'corrupt session');
  });

  test('logout always ends unauthenticated without error flicker', () async {
    final repository = _MockAuthRepository();
    when(
      () => repository.restoreSession(),
    ).thenAnswer((_) async => const Success(null));
    when(
      () => repository.logout(),
    ).thenAnswer((_) async => const Failure(CacheException('clear failed')));

    final container = await createTestContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final sub = container.listen(
      authSessionProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);

    await container.read(authSessionProvider.notifier).restoreSession();
    await container.read(authSessionProvider.notifier).logout();

    expect(
      container.read(authSessionProvider),
      isA<AuthSessionUnauthenticated>(),
    );
  });
}

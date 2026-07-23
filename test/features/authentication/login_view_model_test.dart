import 'package:base_project/core/config/demo_credentials.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/authentication/data/data_sources/fake_auth_remote_data_source.dart';
import 'package:base_project/features/authentication/di/auth_providers.dart';
import 'package:base_project/features/authentication/domain/entities/user.dart';
import 'package:base_project/features/authentication/domain/repositories/auth_repository.dart';
import 'package:base_project/features/authentication/domain/use_cases/login_use_case.dart';
import 'package:base_project/features/authentication/presentation/view_models/login_state.dart';
import 'package:base_project/features/authentication/presentation/view_models/login_view_model.dart';
import 'package:base_project/shared/session/auth_session_provider.dart';
import 'package:base_project/shared/session/auth_session_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../helpers/test_container.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  test('login view model starts in form state', () async {
    final container = await createTestContainer();
    addTearDown(container.dispose);

    final subscription = container.listen(
      loginViewModelProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    expect(container.read(loginViewModelProvider), isA<LoginFormState>());
  });

  test(
    'successful login updates session and clears form credentials',
    () async {
      final container = await createTestContainer(
        overrides: [
          authRemoteDataSourceProvider.overrideWithValue(
            FakeAuthRemoteDataSource(delay: Duration.zero),
          ),
        ],
      );
      addTearDown(container.dispose);

      final loginSub = container.listen(
        loginViewModelProvider,
        (_, __) {},
        fireImmediately: true,
      );
      final sessionSub = container.listen(
        authSessionProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(loginSub.close);
      addTearDown(sessionSub.close);

      final viewModel = container.read(loginViewModelProvider.notifier)
        ..updateEmail(DemoCredentials.email)
        ..updatePassword(DemoCredentials.password);

      await viewModel.login();

      expect(container.read(loginViewModelProvider), isA<LoginSuccess>());
      expect(
        container.read(authSessionProvider),
        isA<AuthSessionAuthenticated>(),
      );
    },
  );

  test('failed login shows general error', () async {
    final container = await createTestContainer(
      overrides: [
        authRemoteDataSourceProvider.overrideWithValue(
          FakeAuthRemoteDataSource(delay: Duration.zero),
        ),
      ],
    );
    addTearDown(container.dispose);

    final loginSub = container.listen(
      loginViewModelProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(loginSub.close);

    final viewModel = container.read(loginViewModelProvider.notifier)
      ..updateEmail('wrong@example.com')
      ..updatePassword('Password123');

    await viewModel.login();

    final state = container.read(loginViewModelProvider);
    expect(state, isA<LoginFormState>());
    expect((state as LoginFormState).generalError, isNotNull);
    expect(state.isSubmitting, isFalse);
  });

  test('duplicate login is ignored while submitting', () async {
    final repository = _MockAuthRepository();
    var calls = 0;

    when(
      () => repository.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async {
      calls++;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return const Success(
        User(id: '1', email: 'demo@example.com', displayName: 'Demo'),
      );
    });
    when(
      () => repository.restoreSession(),
    ).thenAnswer((_) async => const Success(null));
    when(
      () => repository.logout(),
    ).thenAnswer((_) async => const Success(null));

    final container = await createTestContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        loginUseCaseProvider.overrideWithValue(LoginUseCase(repository)),
      ],
    );
    addTearDown(container.dispose);

    final loginSub = container.listen(
      loginViewModelProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(loginSub.close);

    final viewModel = container.read(loginViewModelProvider.notifier)
      ..updateEmail('demo@example.com')
      ..updatePassword('Password123');

    final first = viewModel.login();
    final second = viewModel.login();
    await Future.wait([first, second]);

    expect(calls, 1);
  });

  test('validation failure populates field errors', () async {
    final container = await createTestContainer();
    addTearDown(container.dispose);

    final loginSub = container.listen(
      loginViewModelProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(loginSub.close);

    final viewModel = container.read(loginViewModelProvider.notifier)
      ..updateEmail('bad')
      ..updatePassword('short');

    await viewModel.login();

    final state = container.read(loginViewModelProvider) as LoginFormState;
    expect(state.emailError, isNotNull);
    expect(state.passwordError, isNotNull);
  });

  test('logout clears authenticated session', () async {
    final container = await createTestContainer(
      overrides: [
        authRemoteDataSourceProvider.overrideWithValue(
          FakeAuthRemoteDataSource(delay: Duration.zero),
        ),
      ],
    );
    addTearDown(container.dispose);

    final loginSub = container.listen(
      loginViewModelProvider,
      (_, __) {},
      fireImmediately: true,
    );
    final sessionSub = container.listen(
      authSessionProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(loginSub.close);
    addTearDown(sessionSub.close);

    final login = container.read(loginViewModelProvider.notifier)
      ..updateEmail(DemoCredentials.email)
      ..updatePassword(DemoCredentials.password);
    await login.login();

    await container.read(authSessionProvider.notifier).logout();
    expect(
      container.read(authSessionProvider),
      isA<AuthSessionUnauthenticated>(),
    );
  });
}

import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/authentication/domain/entities/user.dart';
import 'package:base_project/features/profile/di/profile_providers.dart';
import 'package:base_project/features/profile/domain/repositories/profile_repository.dart';
import 'package:base_project/features/profile/domain/use_cases/update_profile_use_case.dart';
import 'package:base_project/features/profile/presentation/view_models/profile_state.dart';
import 'package:base_project/features/profile/presentation/view_models/profile_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../helpers/test_container.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  const user = User(
    id: '1',
    email: 'demo@example.com',
    displayName: 'Demo User',
  );

  test('profile loads successfully', () async {
    final repository = _MockProfileRepository();
    when(
      () => repository.getProfile(),
    ).thenAnswer((_) async => const Success(user));

    final container = await createTestContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(repository),
        updateProfileUseCaseProvider.overrideWithValue(
          UpdateProfileUseCase(repository),
        ),
      ],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(
      profileViewModelProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await container.read(profileViewModelProvider.notifier).load();

    expect(container.read(profileViewModelProvider), isA<ProfileLoaded>());
  });

  test('profile update succeeds', () async {
    final repository = _MockProfileRepository();
    const updated = User(
      id: '1',
      email: 'demo@example.com',
      displayName: 'New Name',
    );
    when(
      () => repository.getProfile(),
    ).thenAnswer((_) async => const Success(user));
    when(
      () => repository.updateDisplayName(any()),
    ).thenAnswer((_) async => const Success(updated));

    final container = await createTestContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(repository),
        updateProfileUseCaseProvider.overrideWithValue(
          UpdateProfileUseCase(repository),
        ),
      ],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(
      profileViewModelProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await container.read(profileViewModelProvider.notifier).load();

    final viewModel = container.read(profileViewModelProvider.notifier)
      ..updateDisplayNameDraft('New Name');
    await viewModel.save();

    final state = container.read(profileViewModelProvider);
    expect(state, isA<ProfileLoaded>());
    expect((state as ProfileLoaded).successMessage, isNotNull);
    expect(state.user.displayName, 'New Name');
  });
}

import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/profile/di/profile_providers.dart';
import 'package:base_project/features/profile/presentation/view_models/profile_state.dart';
import 'package:base_project/shared/session/auth_session_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileViewModel extends StateNotifier<ProfileState> {
  ProfileViewModel(this._ref) : super(const ProfileInitial()) {
    load();
  }

  final Ref _ref;

  Future<void> load() async {
    state = const ProfileLoading();
    final result = await _ref.read(profileRepositoryProvider).getProfile();
    if (!mounted) {
      return;
    }

    state = switch (result) {
      Success(data: final user) => ProfileLoaded(
        user: user,
        displayNameDraft: user.displayName,
      ),
      Failure(error: final error) => ProfileError(error.message),
    };
  }

  void updateDisplayNameDraft(String value) {
    final current = state;
    if (current is! ProfileLoaded || current.isSaving) {
      return;
    }

    state = current.copyWith(
      displayNameDraft: value,
      clearValidationError: true,
      clearApiError: true,
      clearSuccessMessage: true,
    );
  }

  Future<void> save() async {
    final current = state;
    if (current is! ProfileLoaded || current.isSaving) {
      return;
    }

    state = current.copyWith(
      isSaving: true,
      clearValidationError: true,
      clearApiError: true,
      clearSuccessMessage: true,
    );

    final result = await _ref
        .read(updateProfileUseCaseProvider)
        .call(current.displayNameDraft);

    if (!mounted) {
      return;
    }

    switch (result) {
      case Success(data: final user):
        _ref.read(authSessionProvider.notifier).updateUser(user);
        state = ProfileLoaded(
          user: user,
          displayNameDraft: user.displayName,
          successMessage: 'Profile updated',
        );
      case Failure(error: final error):
        if (error is ValidationException) {
          state = current.copyWith(
            isSaving: false,
            validationError: error.fieldErrors['displayName'] ?? error.message,
          );
        } else {
          state = current.copyWith(isSaving: false, apiError: error.message);
        }
    }
  }

  Future<void> retry() => load();
}

final profileViewModelProvider =
    StateNotifierProvider.autoDispose<ProfileViewModel, ProfileState>((ref) {
      return ProfileViewModel(ref);
    });

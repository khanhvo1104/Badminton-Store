import 'package:base_project/features/authentication/domain/entities/user.dart';

sealed class ProfileState {
  const ProfileState();
}

final class ProfileInitial extends ProfileState {
  const ProfileInitial();
}

final class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

final class ProfileLoaded extends ProfileState {
  const ProfileLoaded({
    required this.user,
    required this.displayNameDraft,
    this.isSaving = false,
    this.validationError,
    this.apiError,
    this.successMessage,
  });

  final User user;
  final String displayNameDraft;
  final bool isSaving;
  final String? validationError;
  final String? apiError;
  final String? successMessage;

  ProfileLoaded copyWith({
    User? user,
    String? displayNameDraft,
    bool? isSaving,
    String? validationError,
    String? apiError,
    String? successMessage,
    bool clearValidationError = false,
    bool clearApiError = false,
    bool clearSuccessMessage = false,
  }) {
    return ProfileLoaded(
      user: user ?? this.user,
      displayNameDraft: displayNameDraft ?? this.displayNameDraft,
      isSaving: isSaving ?? this.isSaving,
      validationError: clearValidationError
          ? null
          : validationError ?? this.validationError,
      apiError: clearApiError ? null : apiError ?? this.apiError,
      successMessage: clearSuccessMessage
          ? null
          : successMessage ?? this.successMessage,
    );
  }
}

final class ProfileError extends ProfileState {
  const ProfileError(this.message);

  final String message;
}

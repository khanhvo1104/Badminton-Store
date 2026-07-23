import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/core/utils/validators.dart';
import 'package:base_project/features/authentication/domain/entities/user.dart';
import 'package:base_project/features/profile/domain/repositories/profile_repository.dart';

class UpdateProfileUseCase {
  const UpdateProfileUseCase(this._profileRepository);

  final ProfileRepository _profileRepository;

  Future<Result<User>> call(String displayName) async {
    final validationError = Validators.displayName(displayName);
    if (validationError != null) {
      return Failure(
        ValidationException(
          validationError,
          fieldErrors: {'displayName': validationError},
        ),
      );
    }

    return _profileRepository.updateDisplayName(displayName.trim());
  }
}

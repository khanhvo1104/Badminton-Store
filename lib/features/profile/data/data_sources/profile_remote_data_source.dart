import 'package:base_project/features/profile/data/models/update_profile_request_model.dart';
import 'package:base_project/shared/data/models/user_model.dart';

abstract interface class ProfileRemoteDataSource {
  Future<UserModel> fetchProfile();

  Future<UserModel> updateProfile(UpdateProfileRequestModel request);
}

import 'package:base_project/shared/data/models/user_model.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_response_model.freezed.dart';
part 'auth_response_model.g.dart';

@Freezed(toStringOverride: false)
class AuthResponseModel with _$AuthResponseModel {
  const factory AuthResponseModel({
    @JsonKey(name: 'access_token') required String accessToken,
    required UserModel user,
  }) = _AuthResponseModel;
  const AuthResponseModel._();

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) =>
      _$AuthResponseModelFromJson(json);

  @override
  String toString() => 'AuthResponseModel(accessToken: ***, user: $user)';
}

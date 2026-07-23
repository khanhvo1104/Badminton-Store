import 'package:base_project/features/authentication/domain/entities/user.dart';
import 'package:base_project/shared/data/models/user_model.dart';

abstract final class UserMapper {
  static User toEntity(UserModel model) {
    return User(
      id: model.id,
      email: model.email,
      displayName: model.displayName,
    );
  }
}

import 'package:base_project/core/errors/app_exception.dart';
import 'package:meta/meta.dart';

enum AddressesActionKind { delete, setDefault }

/// Mutation feedback for list-level address actions (delete / set default).
sealed class AddressesActionsState {
  const AddressesActionsState();
}

final class AddressesActionsIdle extends AddressesActionsState {
  const AddressesActionsIdle();
}

@immutable
final class AddressesActionsBusy extends AddressesActionsState {
  const AddressesActionsBusy({required this.addressId, required this.kind});

  final String addressId;
  final AddressesActionKind kind;
}

@immutable
final class AddressesActionsFailure extends AddressesActionsState {
  const AddressesActionsFailure(this.message);

  final String message;
}

@immutable
final class AddressesActionsSuccess extends AddressesActionsState {
  const AddressesActionsSuccess(this.message);

  final String message;
}

/// Vietnamese copy for list load/mutation feedback — never raw backend/SQL text.
abstract final class AddressesActionsUiMessages {
  static const unauthenticated =
      'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
  static const network = 'Không thể kết nối. Vui lòng thử lại.';
  static const loadFailed =
      'Không tải được danh sách địa chỉ. Vui lòng thử lại.';
  static const createSuccess = 'Đã thêm địa chỉ.';
  static const updateSuccess = 'Đã cập nhật địa chỉ.';
  static const deleteSuccess = 'Đã xóa địa chỉ.';
  static const setDefaultSuccess = 'Đã đặt địa chỉ mặc định.';
  static const deleteFailed = 'Không thể xóa địa chỉ. Vui lòng thử lại.';
  static const setDefaultFailed =
      'Không thể đặt địa chỉ mặc định. Vui lòng thử lại.';
}

/// Maps repository [AppException]s to sanitized Vietnamese UI copy.
abstract final class AddressesActionsFailureMapper {
  static String mapListFailure(AppException error) {
    return switch (error) {
      UnauthorizedException() ||
      AuthenticationException() => AddressesActionsUiMessages.unauthenticated,
      NetworkException() => AddressesActionsUiMessages.network,
      _ => AddressesActionsUiMessages.loadFailed,
    };
  }

  static String mapDeleteFailure(AppException error) {
    return switch (error) {
      UnauthorizedException() ||
      AuthenticationException() => AddressesActionsUiMessages.unauthenticated,
      NetworkException() => AddressesActionsUiMessages.network,
      _ => AddressesActionsUiMessages.deleteFailed,
    };
  }

  static String mapSetDefaultFailure(AppException error) {
    return switch (error) {
      UnauthorizedException() ||
      AuthenticationException() => AddressesActionsUiMessages.unauthenticated,
      NetworkException() => AddressesActionsUiMessages.network,
      _ => AddressesActionsUiMessages.setDefaultFailed,
    };
  }
}

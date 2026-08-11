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

/// Vietnamese copy for list mutation failures — never raw backend/SQL text.
abstract final class AddressesActionsUiMessages {
  static const unauthenticated =
      'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
  static const network = 'Không thể kết nối. Vui lòng thử lại.';
  static const deleteFailed = 'Không thể xóa địa chỉ. Vui lòng thử lại.';
  static const setDefaultFailed =
      'Không thể đặt địa chỉ mặc định. Vui lòng thử lại.';
}

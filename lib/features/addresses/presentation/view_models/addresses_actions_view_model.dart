import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/addresses/di/addresses_providers.dart';
import 'package:base_project/features/addresses/presentation/view_models/addresses_actions_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

class AddressesActionsViewModel extends StateNotifier<AddressesActionsState> {
  AddressesActionsViewModel(this._ref) : super(const AddressesActionsIdle());

  final Ref _ref;

  bool get isBusy => state is AddressesActionsBusy;

  Future<bool> delete(String addressId) async {
    if (state is AddressesActionsBusy) {
      return false;
    }

    state = AddressesActionsBusy(
      addressId: addressId,
      kind: AddressesActionKind.delete,
    );

    final result = await _ref.read(addressRepositoryProvider).delete(addressId);
    if (!mounted) {
      return false;
    }

    switch (result) {
      case Success():
        _ref.invalidate(addressesProvider);
        state = const AddressesActionsSuccess(
          AddressesActionsUiMessages.deleteSuccess,
        );
        return true;
      case Failure(error: final error):
        state = AddressesActionsFailure(mapDeleteFailure(error));
        return false;
    }
  }

  Future<bool> setDefault(String addressId) async {
    if (state is AddressesActionsBusy) {
      return false;
    }

    state = AddressesActionsBusy(
      addressId: addressId,
      kind: AddressesActionKind.setDefault,
    );

    final result = await _ref
        .read(addressRepositoryProvider)
        .setDefault(addressId);
    if (!mounted) {
      return false;
    }

    switch (result) {
      case Success():
        _ref.invalidate(addressesProvider);
        state = const AddressesActionsSuccess(
          AddressesActionsUiMessages.setDefaultSuccess,
        );
        return true;
      case Failure(error: final error):
        state = AddressesActionsFailure(mapSetDefaultFailure(error));
        return false;
    }
  }

  void clearFeedback() {
    if (state is AddressesActionsFailure || state is AddressesActionsSuccess) {
      state = const AddressesActionsIdle();
    }
  }

  @visibleForTesting
  static String mapDeleteFailure(AppException error) =>
      AddressesActionsFailureMapper.mapDeleteFailure(error);

  @visibleForTesting
  static String mapSetDefaultFailure(AppException error) =>
      AddressesActionsFailureMapper.mapSetDefaultFailure(error);

  @visibleForTesting
  static String mapListFailure(AppException error) =>
      AddressesActionsFailureMapper.mapListFailure(error);
}

final addressesActionsViewModelProvider =
    StateNotifierProvider.autoDispose<
      AddressesActionsViewModel,
      AddressesActionsState
    >((ref) {
      return AddressesActionsViewModel(ref);
    });

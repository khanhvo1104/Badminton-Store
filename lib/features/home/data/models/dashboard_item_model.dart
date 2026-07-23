import 'package:freezed_annotation/freezed_annotation.dart';

part 'dashboard_item_model.freezed.dart';
part 'dashboard_item_model.g.dart';

@freezed
class DashboardItemModel with _$DashboardItemModel {
  const factory DashboardItemModel({
    required String id,
    required String title,
    required String subtitle,
    @JsonKey(name: 'icon_name') required String iconName,
  }) = _DashboardItemModel;

  factory DashboardItemModel.fromJson(Map<String, dynamic> json) =>
      _$DashboardItemModelFromJson(json);
}

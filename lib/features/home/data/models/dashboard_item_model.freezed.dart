// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'dashboard_item_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

DashboardItemModel _$DashboardItemModelFromJson(Map<String, dynamic> json) {
  return _DashboardItemModel.fromJson(json);
}

/// @nodoc
mixin _$DashboardItemModel {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get subtitle => throw _privateConstructorUsedError;
  @JsonKey(name: 'icon_name')
  String get iconName => throw _privateConstructorUsedError;

  /// Serializes this DashboardItemModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DashboardItemModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DashboardItemModelCopyWith<DashboardItemModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DashboardItemModelCopyWith<$Res> {
  factory $DashboardItemModelCopyWith(
    DashboardItemModel value,
    $Res Function(DashboardItemModel) then,
  ) = _$DashboardItemModelCopyWithImpl<$Res, DashboardItemModel>;
  @useResult
  $Res call({
    String id,
    String title,
    String subtitle,
    @JsonKey(name: 'icon_name') String iconName,
  });
}

/// @nodoc
class _$DashboardItemModelCopyWithImpl<$Res, $Val extends DashboardItemModel>
    implements $DashboardItemModelCopyWith<$Res> {
  _$DashboardItemModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DashboardItemModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? subtitle = null,
    Object? iconName = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            subtitle: null == subtitle
                ? _value.subtitle
                : subtitle // ignore: cast_nullable_to_non_nullable
                      as String,
            iconName: null == iconName
                ? _value.iconName
                : iconName // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DashboardItemModelImplCopyWith<$Res>
    implements $DashboardItemModelCopyWith<$Res> {
  factory _$$DashboardItemModelImplCopyWith(
    _$DashboardItemModelImpl value,
    $Res Function(_$DashboardItemModelImpl) then,
  ) = __$$DashboardItemModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String title,
    String subtitle,
    @JsonKey(name: 'icon_name') String iconName,
  });
}

/// @nodoc
class __$$DashboardItemModelImplCopyWithImpl<$Res>
    extends _$DashboardItemModelCopyWithImpl<$Res, _$DashboardItemModelImpl>
    implements _$$DashboardItemModelImplCopyWith<$Res> {
  __$$DashboardItemModelImplCopyWithImpl(
    _$DashboardItemModelImpl _value,
    $Res Function(_$DashboardItemModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DashboardItemModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? subtitle = null,
    Object? iconName = null,
  }) {
    return _then(
      _$DashboardItemModelImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        subtitle: null == subtitle
            ? _value.subtitle
            : subtitle // ignore: cast_nullable_to_non_nullable
                  as String,
        iconName: null == iconName
            ? _value.iconName
            : iconName // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$DashboardItemModelImpl implements _DashboardItemModel {
  const _$DashboardItemModelImpl({
    required this.id,
    required this.title,
    required this.subtitle,
    @JsonKey(name: 'icon_name') required this.iconName,
  });

  factory _$DashboardItemModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$DashboardItemModelImplFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  final String subtitle;
  @override
  @JsonKey(name: 'icon_name')
  final String iconName;

  @override
  String toString() {
    return 'DashboardItemModel(id: $id, title: $title, subtitle: $subtitle, iconName: $iconName)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DashboardItemModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.subtitle, subtitle) ||
                other.subtitle == subtitle) &&
            (identical(other.iconName, iconName) ||
                other.iconName == iconName));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, title, subtitle, iconName);

  /// Create a copy of DashboardItemModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DashboardItemModelImplCopyWith<_$DashboardItemModelImpl> get copyWith =>
      __$$DashboardItemModelImplCopyWithImpl<_$DashboardItemModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$DashboardItemModelImplToJson(this);
  }
}

abstract class _DashboardItemModel implements DashboardItemModel {
  const factory _DashboardItemModel({
    required final String id,
    required final String title,
    required final String subtitle,
    @JsonKey(name: 'icon_name') required final String iconName,
  }) = _$DashboardItemModelImpl;

  factory _DashboardItemModel.fromJson(Map<String, dynamic> json) =
      _$DashboardItemModelImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  String get subtitle;
  @override
  @JsonKey(name: 'icon_name')
  String get iconName;

  /// Create a copy of DashboardItemModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DashboardItemModelImplCopyWith<_$DashboardItemModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

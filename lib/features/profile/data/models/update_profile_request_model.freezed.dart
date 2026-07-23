// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'update_profile_request_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

UpdateProfileRequestModel _$UpdateProfileRequestModelFromJson(
  Map<String, dynamic> json,
) {
  return _UpdateProfileRequestModel.fromJson(json);
}

/// @nodoc
mixin _$UpdateProfileRequestModel {
  @JsonKey(name: 'display_name')
  String get displayName => throw _privateConstructorUsedError;

  /// Serializes this UpdateProfileRequestModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of UpdateProfileRequestModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UpdateProfileRequestModelCopyWith<UpdateProfileRequestModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UpdateProfileRequestModelCopyWith<$Res> {
  factory $UpdateProfileRequestModelCopyWith(
    UpdateProfileRequestModel value,
    $Res Function(UpdateProfileRequestModel) then,
  ) = _$UpdateProfileRequestModelCopyWithImpl<$Res, UpdateProfileRequestModel>;
  @useResult
  $Res call({@JsonKey(name: 'display_name') String displayName});
}

/// @nodoc
class _$UpdateProfileRequestModelCopyWithImpl<
  $Res,
  $Val extends UpdateProfileRequestModel
>
    implements $UpdateProfileRequestModelCopyWith<$Res> {
  _$UpdateProfileRequestModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of UpdateProfileRequestModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? displayName = null}) {
    return _then(
      _value.copyWith(
            displayName: null == displayName
                ? _value.displayName
                : displayName // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$UpdateProfileRequestModelImplCopyWith<$Res>
    implements $UpdateProfileRequestModelCopyWith<$Res> {
  factory _$$UpdateProfileRequestModelImplCopyWith(
    _$UpdateProfileRequestModelImpl value,
    $Res Function(_$UpdateProfileRequestModelImpl) then,
  ) = __$$UpdateProfileRequestModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({@JsonKey(name: 'display_name') String displayName});
}

/// @nodoc
class __$$UpdateProfileRequestModelImplCopyWithImpl<$Res>
    extends
        _$UpdateProfileRequestModelCopyWithImpl<
          $Res,
          _$UpdateProfileRequestModelImpl
        >
    implements _$$UpdateProfileRequestModelImplCopyWith<$Res> {
  __$$UpdateProfileRequestModelImplCopyWithImpl(
    _$UpdateProfileRequestModelImpl _value,
    $Res Function(_$UpdateProfileRequestModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of UpdateProfileRequestModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? displayName = null}) {
    return _then(
      _$UpdateProfileRequestModelImpl(
        displayName: null == displayName
            ? _value.displayName
            : displayName // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$UpdateProfileRequestModelImpl implements _UpdateProfileRequestModel {
  const _$UpdateProfileRequestModelImpl({
    @JsonKey(name: 'display_name') required this.displayName,
  });

  factory _$UpdateProfileRequestModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$UpdateProfileRequestModelImplFromJson(json);

  @override
  @JsonKey(name: 'display_name')
  final String displayName;

  @override
  String toString() {
    return 'UpdateProfileRequestModel(displayName: $displayName)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UpdateProfileRequestModelImpl &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, displayName);

  /// Create a copy of UpdateProfileRequestModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UpdateProfileRequestModelImplCopyWith<_$UpdateProfileRequestModelImpl>
  get copyWith =>
      __$$UpdateProfileRequestModelImplCopyWithImpl<
        _$UpdateProfileRequestModelImpl
      >(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UpdateProfileRequestModelImplToJson(this);
  }
}

abstract class _UpdateProfileRequestModel implements UpdateProfileRequestModel {
  const factory _UpdateProfileRequestModel({
    @JsonKey(name: 'display_name') required final String displayName,
  }) = _$UpdateProfileRequestModelImpl;

  factory _UpdateProfileRequestModel.fromJson(Map<String, dynamic> json) =
      _$UpdateProfileRequestModelImpl.fromJson;

  @override
  @JsonKey(name: 'display_name')
  String get displayName;

  /// Create a copy of UpdateProfileRequestModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UpdateProfileRequestModelImplCopyWith<_$UpdateProfileRequestModelImpl>
  get copyWith => throw _privateConstructorUsedError;
}

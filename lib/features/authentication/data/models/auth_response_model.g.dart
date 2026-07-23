// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_response_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AuthResponseModelImpl _$$AuthResponseModelImplFromJson(
  Map<String, dynamic> json,
) => _$AuthResponseModelImpl(
  accessToken: json['access_token'] as String,
  user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
);

Map<String, dynamic> _$$AuthResponseModelImplToJson(
  _$AuthResponseModelImpl instance,
) => <String, dynamic>{
  'access_token': instance.accessToken,
  'user': instance.user,
};

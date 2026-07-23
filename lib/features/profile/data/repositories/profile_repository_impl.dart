import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/errors/error_mapper.dart';
import 'package:base_project/core/logging/app_logger.dart';
import 'package:base_project/core/network/network_info.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/authentication/domain/entities/user.dart';
import 'package:base_project/features/profile/data/data_sources/profile_remote_data_source.dart';
import 'package:base_project/features/profile/data/models/update_profile_request_model.dart';
import 'package:base_project/features/profile/domain/repositories/profile_repository.dart';
import 'package:base_project/shared/data/mappers/user_mapper.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl({
    required ProfileRemoteDataSource remoteDataSource,
    required NetworkInfo networkInfo,
    required ErrorMapper errorMapper,
    required AppLogger logger,
  }) : _remoteDataSource = remoteDataSource,
       _networkInfo = networkInfo,
       _errorMapper = errorMapper,
       _logger = logger;

  final ProfileRemoteDataSource _remoteDataSource;
  final NetworkInfo _networkInfo;
  final ErrorMapper _errorMapper;
  final AppLogger _logger;

  @override
  Future<Result<User>> getProfile() async {
    try {
      if (!await _networkInfo.isConnected) {
        return const Failure(NetworkException('No internet connection'));
      }

      final model = await _remoteDataSource.fetchProfile();
      return Success(UserMapper.toEntity(model));
    } on Object catch (error, stackTrace) {
      final mapped = _errorMapper.map(error, stackTrace);
      _logger.error(
        'Failed to load profile',
        error: mapped,
        stackTrace: stackTrace,
      );
      return Failure(mapped);
    }
  }

  @override
  Future<Result<User>> updateDisplayName(String displayName) async {
    try {
      if (!await _networkInfo.isConnected) {
        return const Failure(NetworkException('No internet connection'));
      }

      final model = await _remoteDataSource.updateProfile(
        UpdateProfileRequestModel(displayName: displayName),
      );
      return Success(UserMapper.toEntity(model));
    } on Object catch (error, stackTrace) {
      final mapped = _errorMapper.map(error, stackTrace);
      _logger.error(
        'Failed to update profile',
        error: mapped,
        stackTrace: stackTrace,
      );
      return Failure(mapped);
    }
  }
}

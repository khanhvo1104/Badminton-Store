import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/errors/error_mapper.dart';
import 'package:base_project/core/logging/app_logger.dart';
import 'package:base_project/core/network/network_info.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/authentication/data/data_sources/auth_local_data_source.dart';
import 'package:base_project/features/authentication/data/data_sources/auth_remote_data_source.dart';
import 'package:base_project/features/authentication/data/models/login_request_model.dart';
import 'package:base_project/features/authentication/domain/entities/user.dart';
import 'package:base_project/features/authentication/domain/repositories/auth_repository.dart';
import 'package:base_project/shared/data/mappers/user_mapper.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required AuthLocalDataSource localDataSource,
    required NetworkInfo networkInfo,
    required ErrorMapper errorMapper,
    required AppLogger logger,
  }) : _remoteDataSource = remoteDataSource,
       _localDataSource = localDataSource,
       _networkInfo = networkInfo,
       _errorMapper = errorMapper,
       _logger = logger;

  final AuthRemoteDataSource _remoteDataSource;
  final AuthLocalDataSource _localDataSource;
  final NetworkInfo _networkInfo;
  final ErrorMapper _errorMapper;
  final AppLogger _logger;

  @override
  Future<Result<User>> login({
    required String email,
    required String password,
  }) async {
    try {
      if (!await _networkInfo.isConnected) {
        return const Failure(NetworkException('No internet connection'));
      }

      final response = await _remoteDataSource.login(
        LoginRequestModel(email: email, password: password),
      );

      await _localDataSource.saveSession(
        accessToken: response.accessToken,
        user: response.user,
      );

      return Success(UserMapper.toEntity(response.user));
    } on Object catch (error, stackTrace) {
      final mapped = _errorMapper.map(error, stackTrace);
      _logger.error('Login failed', error: mapped, stackTrace: stackTrace);
      return Failure(mapped);
    }
  }

  @override
  Future<Result<User?>> restoreSession() async {
    try {
      final remoteUser = await _remoteDataSource.getCurrentUser();
      if (remoteUser == null) {
        await _localDataSource.clearSession();
        return const Success(null);
      }
      await _localDataSource.saveSession(
        accessToken: _remoteDataSource.currentAccessToken ?? '',
        user: remoteUser,
      );
      return Success(UserMapper.toEntity(remoteUser));
    } on Object catch (error, stackTrace) {
      final mapped = _errorMapper.map(error, stackTrace);
      _logger.error(
        'Session restore failed',
        error: mapped,
        stackTrace: stackTrace,
      );
      return Failure(mapped);
    }
  }

  @override
  Future<Result<void>> logout() async {
    try {
      await _remoteDataSource.logout();
      await _localDataSource.clearSession();
      return const Success(null);
    } on Object catch (error, stackTrace) {
      final mapped = _errorMapper.map(error, stackTrace);
      _logger.error('Logout failed', error: mapped, stackTrace: stackTrace);
      return Failure(mapped);
    }
  }
}

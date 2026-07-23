import 'package:base_project/core/errors/error_mapper.dart';
import 'package:base_project/core/logging/logger_provider.dart';
import 'package:base_project/core/network/network_info_provider.dart';
import 'package:base_project/core/storage/storage_providers.dart';
import 'package:base_project/features/authentication/data/data_sources/auth_local_data_source.dart';
import 'package:base_project/features/authentication/data/data_sources/auth_local_data_source_impl.dart';
import 'package:base_project/features/authentication/data/data_sources/auth_remote_data_source.dart';
import 'package:base_project/features/authentication/data/data_sources/fake_auth_remote_data_source.dart';
import 'package:base_project/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:base_project/features/authentication/domain/repositories/auth_repository.dart';
import 'package:base_project/features/authentication/domain/use_cases/login_use_case.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Composition root for authentication. Presentation imports this module,
/// not concrete data-source files.
final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return FakeAuthRemoteDataSource();
});

final authLocalDataSourceProvider = Provider<AuthLocalDataSource>((ref) {
  return AuthLocalDataSourceImpl(ref.watch(secureStorageServiceProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final logger = ref.watch(appLoggerProvider);
  return AuthRepositoryImpl(
    remoteDataSource: ref.watch(authRemoteDataSourceProvider),
    localDataSource: ref.watch(authLocalDataSourceProvider),
    networkInfo: ref.watch(networkInfoProvider),
    errorMapper: ErrorMapper(logger),
    logger: logger,
  );
});

final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
  return LoginUseCase(ref.watch(authRepositoryProvider));
});

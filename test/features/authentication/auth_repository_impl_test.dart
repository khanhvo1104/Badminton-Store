import 'package:base_project/core/config/demo_credentials.dart';
import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/errors/error_mapper.dart';
import 'package:base_project/core/logging/app_logger.dart';
import 'package:base_project/core/network/network_info.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/core/storage/secure_storage_service.dart';
import 'package:base_project/features/authentication/data/data_sources/auth_local_data_source_impl.dart';
import 'package:base_project/features/authentication/data/data_sources/fake_auth_remote_data_source.dart';
import 'package:base_project/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:base_project/features/authentication/domain/entities/user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeSecureStorageService storage;
  late FakeNetworkInfo networkInfo;
  late FakeAuthRemoteDataSource remote;
  late AuthRepositoryImpl repository;

  setUp(() {
    storage = FakeSecureStorageService();
    networkInfo = FakeNetworkInfo();
    remote = FakeAuthRemoteDataSource(delay: Duration.zero);
    final logger = AppLogger();
    repository = AuthRepositoryImpl(
      remoteDataSource: remote,
      localDataSource: AuthLocalDataSourceImpl(storage),
      networkInfo: networkInfo,
      errorMapper: ErrorMapper(logger),
      logger: logger,
    );
  });

  test('login succeeds with demo credentials', () async {
    final result = await repository.login(
      email: DemoCredentials.email,
      password: DemoCredentials.password,
    );

    expect(result, isA<Success<User>>());
    final user = (result as Success<User>).data;
    expect(user.email, DemoCredentials.email);
    expect(await storage.read(key: 'access_token'), isNotNull);
  });

  test('login fails with invalid credentials', () async {
    final result = await repository.login(
      email: 'wrong@example.com',
      password: 'Password123',
    );

    expect(result, isA<Failure<User>>());
    expect((result as Failure<User>).error, isA<UnauthorizedException>());
  });

  test('login fails when offline', () async {
    networkInfo.isConnectedValue = false;

    final result = await repository.login(
      email: DemoCredentials.email,
      password: DemoCredentials.password,
    );

    expect(result, isA<Failure<User>>());
    expect((result as Failure<User>).error, isA<NetworkException>());
  });

  test('logout clears session data', () async {
    await repository.login(
      email: DemoCredentials.email,
      password: DemoCredentials.password,
    );

    final logoutResult = await repository.logout();
    expect(logoutResult, isA<Success<void>>());
    expect(await storage.read(key: 'access_token'), isNull);
  });
}

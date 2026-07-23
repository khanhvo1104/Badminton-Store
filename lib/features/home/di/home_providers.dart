import 'package:base_project/core/errors/error_mapper.dart';
import 'package:base_project/core/logging/logger_provider.dart';
import 'package:base_project/core/network/network_info_provider.dart';
import 'package:base_project/features/home/data/data_sources/fake_home_remote_data_source.dart';
import 'package:base_project/features/home/data/data_sources/home_remote_data_source.dart';
import 'package:base_project/features/home/data/repositories/home_repository_impl.dart';
import 'package:base_project/features/home/domain/repositories/home_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final homeRemoteDataSourceProvider = Provider<HomeRemoteDataSource>((ref) {
  return FakeHomeRemoteDataSource();
});

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  final logger = ref.watch(appLoggerProvider);
  return HomeRepositoryImpl(
    remoteDataSource: ref.watch(homeRemoteDataSourceProvider),
    networkInfo: ref.watch(networkInfoProvider),
    errorMapper: ErrorMapper(logger),
    logger: logger,
  );
});

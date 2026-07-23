import 'package:base_project/core/errors/error_mapper.dart';
import 'package:base_project/core/logging/app_logger.dart';
import 'package:base_project/core/network/network_info.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/home/data/data_sources/fake_home_remote_data_source.dart';
import 'package:base_project/features/home/data/repositories/home_repository_impl.dart';
import 'package:base_project/features/home/domain/entities/dashboard_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeNetworkInfo networkInfo;
  late AppLogger logger;

  setUp(() {
    networkInfo = FakeNetworkInfo();
    logger = AppLogger();
  });

  HomeRepositoryImpl buildRepo(FakeHomeRemoteDataSource remote) {
    return HomeRepositoryImpl(
      remoteDataSource: remote,
      networkInfo: networkInfo,
      errorMapper: ErrorMapper(logger),
      logger: logger,
    );
  }

  test('returns dashboard items', () async {
    final result = await buildRepo(
      FakeHomeRemoteDataSource(delay: Duration.zero),
    ).getDashboardItems();
    expect(result, isA<Success<List<DashboardItem>>>());
    expect((result as Success<List<DashboardItem>>).data, isNotEmpty);
  });

  test('returns empty list', () async {
    final result = await buildRepo(
      FakeHomeRemoteDataSource(delay: Duration.zero, returnEmpty: true),
    ).getDashboardItems();
    expect(result, isA<Success<List<DashboardItem>>>());
    expect((result as Success<List<DashboardItem>>).data, isEmpty);
  });

  test('maps remote failures', () async {
    final result = await buildRepo(
      FakeHomeRemoteDataSource(delay: Duration.zero, shouldFail: true),
    ).getDashboardItems();
    expect(result, isA<Failure<List<DashboardItem>>>());
  });
}

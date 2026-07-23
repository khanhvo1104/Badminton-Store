import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/errors/error_mapper.dart';
import 'package:base_project/core/logging/app_logger.dart';
import 'package:base_project/core/network/network_info.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/home/data/data_sources/home_remote_data_source.dart';
import 'package:base_project/features/home/domain/entities/dashboard_item.dart';
import 'package:base_project/features/home/domain/repositories/home_repository.dart';

class HomeRepositoryImpl implements HomeRepository {
  HomeRepositoryImpl({
    required HomeRemoteDataSource remoteDataSource,
    required NetworkInfo networkInfo,
    required ErrorMapper errorMapper,
    required AppLogger logger,
  }) : _remoteDataSource = remoteDataSource,
       _networkInfo = networkInfo,
       _errorMapper = errorMapper,
       _logger = logger;

  final HomeRemoteDataSource _remoteDataSource;
  final NetworkInfo _networkInfo;
  final ErrorMapper _errorMapper;
  final AppLogger _logger;

  @override
  Future<Result<List<DashboardItem>>> getDashboardItems() async {
    try {
      if (!await _networkInfo.isConnected) {
        return const Failure(NetworkException('No internet connection'));
      }

      final models = await _remoteDataSource.fetchDashboardItems();
      final items = models
          .map(
            (model) => DashboardItem(
              id: model.id,
              title: model.title,
              subtitle: model.subtitle,
              iconName: model.iconName,
            ),
          )
          .toList(growable: false);

      return Success(items);
    } on Object catch (error, stackTrace) {
      final mapped = _errorMapper.map(error, stackTrace);
      _logger.error(
        'Failed to load dashboard',
        error: mapped,
        stackTrace: stackTrace,
      );
      return Failure(mapped);
    }
  }
}

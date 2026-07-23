import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/features/home/data/data_sources/home_remote_data_source.dart';
import 'package:base_project/features/home/data/models/dashboard_item_model.dart';

class FakeHomeRemoteDataSource implements HomeRemoteDataSource {
  FakeHomeRemoteDataSource({
    this.delay = const Duration(milliseconds: 500),
    this.shouldFail = false,
    this.returnEmpty = false,
  });

  final Duration delay;
  final bool shouldFail;
  final bool returnEmpty;

  @override
  Future<List<DashboardItemModel>> fetchDashboardItems() async {
    await Future<void>.delayed(delay);

    if (shouldFail) {
      throw const ServerException(
        'Simulated home API failure',
        statusCode: 500,
      );
    }

    if (returnEmpty) {
      return const [];
    }

    return const [
      DashboardItemModel(
        id: '1',
        title: 'Active sessions',
        subtitle: '3 devices signed in',
        iconName: 'devices',
      ),
      DashboardItemModel(
        id: '2',
        title: 'Security score',
        subtitle: 'Strong — MFA enabled',
        iconName: 'security',
      ),
      DashboardItemModel(
        id: '3',
        title: 'Notifications',
        subtitle: '2 unread alerts',
        iconName: 'notifications',
      ),
      DashboardItemModel(
        id: '4',
        title: 'Storage',
        subtitle: '64% of quota used',
        iconName: 'storage',
      ),
    ];
  }
}

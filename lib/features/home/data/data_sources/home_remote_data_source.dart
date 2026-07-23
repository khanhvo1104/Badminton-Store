import 'package:base_project/features/home/data/models/dashboard_item_model.dart';

abstract interface class HomeRemoteDataSource {
  Future<List<DashboardItemModel>> fetchDashboardItems();
}

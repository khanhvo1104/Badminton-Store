import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/home/domain/entities/dashboard_item.dart';

abstract interface class HomeRepository {
  Future<Result<List<DashboardItem>>> getDashboardItems();
}

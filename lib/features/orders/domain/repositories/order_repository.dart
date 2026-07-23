import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/orders/domain/entities/order.dart';

/// Order history and placement. Implementations arrive in a later milestone.
abstract interface class OrderRepository {
  Future<Result<List<Order>>> list({int page = 1, int pageSize = 20});

  Future<Result<Order>> getById(String id);
}

import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/product/domain/entities/product.dart';

/// Product search and suggestions. Implementations arrive in a later milestone.
abstract interface class SearchRepository {
  Future<Result<List<Product>>> search({
    required String query,
    int page = 1,
    int pageSize = 20,
  });

  Future<Result<List<String>>> recentQueries();

  Future<Result<void>> clearRecentQueries();
}

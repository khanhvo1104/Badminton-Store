import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/product/domain/entities/product.dart';

/// Catalog product access. Implementations arrive in a later milestone.
abstract interface class ProductRepository {
  Future<Result<Product>> getById(String id);

  Future<Result<List<Product>>> list({
    String? categoryId,
    String? brandId,
    int page = 1,
    int pageSize = 20,
  });
}

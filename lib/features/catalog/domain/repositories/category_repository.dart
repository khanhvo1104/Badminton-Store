import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/catalog/domain/entities/category.dart';

/// Product category taxonomy. Implementations arrive in a later milestone.
abstract interface class CategoryRepository {
  Future<Result<List<Category>>> list();

  Future<Result<Category>> getById(String id);

  Future<Result<Category>> getBySlug(String slug);
}

import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/catalog/domain/entities/brand.dart';

/// Brand directory. Wired via SupabaseBrandRepository.
abstract interface class BrandRepository {
  Future<Result<List<Brand>>> list();

  Future<Result<Brand>> getById(String id);
}

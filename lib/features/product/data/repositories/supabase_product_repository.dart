import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/product/data/supabase_product_mapper.dart';
import 'package:base_project/features/product/domain/entities/product.dart';
import 'package:base_project/features/product/domain/entities/product_variant.dart';
import 'package:base_project/features/product/domain/repositories/product_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseProductRepository implements ProductRepository {
  SupabaseProductRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<Product>> getById(String id) async {
    try {
      final productRow = await _client
          .from('products')
          .select()
          .eq('id', id)
          .single();
      final imageRows = await _client
          .from('product_images')
          .select()
          .eq('product_id', id)
          .order('sort_order');
      final variantRows = await _client
          .from('product_variants')
          .select()
          .eq('product_id', id)
          .order('sort_order');

      final images = imageRows
          .map((row) => productImageFromRow(Map<String, dynamic>.from(row)))
          .toList(growable: false);

      final variants = <ProductVariant>[];
      for (final row in variantRows) {
        final map = Map<String, dynamic>.from(row);
        final availability = await _client.rpc<List<dynamic>>(
          'get_variant_availability',
          params: {'p_variant_id': map['id']},
        );
        int? availableQuantity;
        if (availability.isNotEmpty) {
          final availabilityRow = Map<String, dynamic>.from(
            availability.first as Map,
          );
          availableQuantity = availabilityRow['available_quantity'] as int?;
        }
        variants.add(
          productVariantFromRow(
            map,
            availableQuantity: availableQuantity,
          ),
        );
      }

      return Success(
        productFromDetailRow(
          Map<String, dynamic>.from(productRow),
          images: images,
          variants: variants,
        ),
      );
    } on PostgrestException catch (error, stackTrace) {
      return Failure(
        DatabaseException(
          error.message,
          code: error.code,
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<List<Product>>> list({
    String? categoryId,
    String? brandId,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      var query = _client.from('product_catalog').select();
      if (categoryId != null && categoryId.isNotEmpty) {
        query = query.eq('category_id', categoryId);
      }
      if (brandId != null && brandId.isNotEmpty) {
        query = query.eq('brand_id', brandId);
      }

      final from = (page - 1) * pageSize;
      final to = from + pageSize - 1;
      final rows = await query
          .order('is_featured', ascending: false)
          .order('published_at', ascending: false)
          .range(from, to);

      return Success(
        rows
            .map((row) => productFromCatalogRow(Map<String, dynamic>.from(row)))
            .toList(growable: false),
      );
    } on PostgrestException catch (error, stackTrace) {
      return Failure(
        DatabaseException(
          error.message,
          code: error.code,
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }
}

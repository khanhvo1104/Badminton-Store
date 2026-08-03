import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/core/supabase/supabase_row.dart';
import 'package:base_project/features/catalog/domain/entities/brand.dart';
import 'package:base_project/features/catalog/domain/repositories/brand_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseBrandRepository implements BrandRepository {
  SupabaseBrandRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<Brand>> getById(String id) async {
    try {
      final row = await _client.from('brands').select().eq('id', id).single();
      return Success(_mapBrand(Map<String, dynamic>.from(row)));
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
  Future<Result<List<Brand>>> list() async {
    try {
      final rows = await _client.from('brands').select().order('sort_order');
      return Success(
        rows
            .map((row) => _mapBrand(Map<String, dynamic>.from(row)))
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

  Brand _mapBrand(SupabaseRow row) {
    return Brand(
      id: requireString(row, 'id'),
      name: requireString(row, 'name'),
      slug: requireString(row, 'slug'),
      description: optionalString(row, 'description'),
      logoPath: optionalString(row, 'logo_path'),
      websiteUrl: optionalString(row, 'website_url'),
      countryOfOrigin: optionalString(row, 'country_of_origin'),
      sortOrder: requireInt(row, 'sort_order'),
      isActive: requireBool(row, 'is_active', fallback: true),
    );
  }
}

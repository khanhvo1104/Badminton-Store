import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/core/supabase/supabase_row.dart';
import 'package:base_project/features/catalog/domain/entities/brand.dart';
import 'package:base_project/features/catalog/domain/repositories/brand_repository.dart';
import 'package:meta/meta.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Fetches a single brand row by table + equality filter.
@visibleForTesting
typedef BrandSingleQuery =
    Future<Map<String, dynamic>> Function({
      required String table,
      required String filterColumn,
      required String filterValue,
    });

/// Fetches brand rows ordered by a single column.
@visibleForTesting
typedef BrandOrderedListQuery =
    Future<List<Map<String, dynamic>>> Function({
      required String table,
      required String orderColumn,
    });

final class SupabaseBrandRepository implements BrandRepository {
  SupabaseBrandRepository(SupabaseClient client)
    : _fetchSingle =
          (({
            required String table,
            required String filterColumn,
            required String filterValue,
          }) async {
            final row = await client
                .from(table)
                .select()
                .eq(filterColumn, filterValue)
                .single();
            return Map<String, dynamic>.from(row);
          }),
      _fetchOrderedList =
          (({required String table, required String orderColumn}) async {
            final rows = await client.from(table).select().order(orderColumn);
            return rows
                .map((row) => Map<String, dynamic>.from(row))
                .toList(growable: false);
          });

  @visibleForTesting
  SupabaseBrandRepository.testing({
    required BrandSingleQuery fetchSingle,
    required BrandOrderedListQuery fetchOrderedList,
  }) : _fetchSingle = fetchSingle,
       _fetchOrderedList = fetchOrderedList;

  final BrandSingleQuery _fetchSingle;
  final BrandOrderedListQuery _fetchOrderedList;

  @override
  Future<Result<Brand>> getById(String id) async {
    try {
      final row = await _fetchSingle(
        table: 'brands',
        filterColumn: 'id',
        filterValue: id,
      );
      return Success(_mapBrand(row));
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
      final rows = await _fetchOrderedList(
        table: 'brands',
        orderColumn: 'sort_order',
      );
      return Success(rows.map(_mapBrand).toList(growable: false));
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

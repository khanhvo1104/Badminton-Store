import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/core/supabase/supabase_row.dart';
import 'package:base_project/features/catalog/domain/entities/category.dart';
import 'package:base_project/features/catalog/domain/repositories/category_repository.dart';
import 'package:meta/meta.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Fetches a single category row by table + equality filter.
@visibleForTesting
typedef CategorySingleQuery =
    Future<Map<String, dynamic>> Function({
      required String table,
      required String filterColumn,
      required String filterValue,
    });

/// Fetches category rows ordered by a single column.
@visibleForTesting
typedef CategoryOrderedListQuery =
    Future<List<Map<String, dynamic>>> Function({
      required String table,
      required String orderColumn,
    });

final class SupabaseCategoryRepository implements CategoryRepository {
  SupabaseCategoryRepository(SupabaseClient client)
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
  SupabaseCategoryRepository.testing({
    required CategorySingleQuery fetchSingle,
    required CategoryOrderedListQuery fetchOrderedList,
  }) : _fetchSingle = fetchSingle,
       _fetchOrderedList = fetchOrderedList;

  final CategorySingleQuery _fetchSingle;
  final CategoryOrderedListQuery _fetchOrderedList;

  @override
  Future<Result<Category>> getById(String id) async {
    try {
      final row = await _fetchSingle(
        table: 'categories',
        filterColumn: 'id',
        filterValue: id,
      );
      return Success(_mapCategory(row));
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
  Future<Result<Category>> getBySlug(String slug) async {
    try {
      final row = await _fetchSingle(
        table: 'categories',
        filterColumn: 'slug',
        filterValue: slug,
      );
      return Success(_mapCategory(row));
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
  Future<Result<List<Category>>> list() async {
    try {
      final rows = await _fetchOrderedList(
        table: 'categories',
        orderColumn: 'sort_order',
      );
      return Success(rows.map(_mapCategory).toList(growable: false));
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

  Category _mapCategory(SupabaseRow row) {
    return Category(
      id: requireString(row, 'id'),
      name: requireString(row, 'name'),
      slug: requireString(row, 'slug'),
      parentId: optionalString(row, 'parent_id'),
      description: optionalString(row, 'description'),
      imagePath: optionalString(row, 'image_path'),
      sortOrder: requireInt(row, 'sort_order'),
      isActive: requireBool(row, 'is_active', fallback: true),
    );
  }
}

import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/core/supabase/supabase_row.dart';
import 'package:base_project/features/catalog/domain/entities/category.dart';
import 'package:base_project/features/catalog/domain/repositories/category_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseCategoryRepository implements CategoryRepository {
  SupabaseCategoryRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<Category>> getById(String id) async {
    try {
      final row = await _client
          .from('categories')
          .select()
          .eq('id', id)
          .single();
      return Success(_mapCategory(Map<String, dynamic>.from(row)));
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
      final row = await _client
          .from('categories')
          .select()
          .eq('slug', slug)
          .single();
      return Success(_mapCategory(Map<String, dynamic>.from(row)));
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
      final rows = await _client
          .from('categories')
          .select()
          .order('sort_order');
      return Success(
        rows
            .map((row) => _mapCategory(Map<String, dynamic>.from(row)))
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

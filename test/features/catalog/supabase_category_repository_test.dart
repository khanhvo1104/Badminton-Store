import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/catalog/data/repositories/supabase_category_repository.dart';
import 'package:base_project/features/catalog/domain/entities/category.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _categoryId = '20000000-0000-4000-8000-000000000001';
const _parentId = '20000000-0000-4000-8000-000000000099';

Map<String, dynamic> _categoryRow({
  String id = _categoryId,
  String name = 'Rackets',
  String slug = 'rackets',
  String? parentId = _parentId,
  String? description = 'Badminton rackets',
  String? imagePath = 'categories/rackets.png',
  int sortOrder = 1,
  bool isActive = true,
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'slug': slug,
    'parent_id': parentId,
    'description': description,
    'image_path': imagePath,
    'sort_order': sortOrder,
    'is_active': isActive,
  };
}

void main() {
  test('getById targets categories.id and maps all fields', () async {
    late String capturedTable;
    late String capturedColumn;
    late String capturedValue;

    final repo = SupabaseCategoryRepository.testing(
      fetchSingle:
          ({
            required String table,
            required String filterColumn,
            required String filterValue,
          }) async {
            capturedTable = table;
            capturedColumn = filterColumn;
            capturedValue = filterValue;
            return _categoryRow();
          },
      fetchOrderedList:
          ({required String table, required String orderColumn}) async =>
              const [],
    );

    final result = await repo.getById(_categoryId);

    expect(capturedTable, 'categories');
    expect(capturedColumn, 'id');
    expect(capturedValue, _categoryId);
    expect(result, isA<Success<Category>>());
    final category = (result as Success<Category>).data;
    expect(category.id, _categoryId);
    expect(category.name, 'Rackets');
    expect(category.slug, 'rackets');
    expect(category.parentId, _parentId);
    expect(category.description, 'Badminton rackets');
    expect(category.imagePath, 'categories/rackets.png');
    expect(category.sortOrder, 1);
    expect(category.isActive, isTrue);
  });

  test('getBySlug targets categories.slug', () async {
    late String capturedTable;
    late String capturedColumn;
    late String capturedValue;

    final repo = SupabaseCategoryRepository.testing(
      fetchSingle:
          ({
            required String table,
            required String filterColumn,
            required String filterValue,
          }) async {
            capturedTable = table;
            capturedColumn = filterColumn;
            capturedValue = filterValue;
            return _categoryRow(slug: 'shoes');
          },
      fetchOrderedList:
          ({required String table, required String orderColumn}) async =>
              const [],
    );

    final result = await repo.getBySlug('shoes');

    expect(capturedTable, 'categories');
    expect(capturedColumn, 'slug');
    expect(capturedValue, 'shoes');
    expect(result, isA<Success<Category>>());
    expect((result as Success<Category>).data.slug, 'shoes');
  });

  test('getById maps optional nulls and is_active fallback', () async {
    final repo = SupabaseCategoryRepository.testing(
      fetchSingle:
          ({
            required String table,
            required String filterColumn,
            required String filterValue,
          }) async {
            return _categoryRow(
              parentId: null,
              description: null,
              imagePath: null,
            )..remove('is_active');
          },
      fetchOrderedList:
          ({required String table, required String orderColumn}) async =>
              const [],
    );

    final category =
        ((await repo.getById(_categoryId)) as Success<Category>).data;
    expect(category.parentId, isNull);
    expect(category.description, isNull);
    expect(category.imagePath, isNull);
    expect(category.isActive, isTrue);
  });

  test('list targets categories ordered by sort_order', () async {
    late String capturedTable;
    late String capturedOrder;

    final repo = SupabaseCategoryRepository.testing(
      fetchSingle:
          ({
            required String table,
            required String filterColumn,
            required String filterValue,
          }) async => throw StateError('unused'),
      fetchOrderedList:
          ({required String table, required String orderColumn}) async {
            capturedTable = table;
            capturedOrder = orderColumn;
            return [
              _categoryRow(
                id: '20000000-0000-4000-8000-000000000002',
                name: 'Shoes',
                slug: 'shoes',
                sortOrder: 1,
              ),
              _categoryRow(sortOrder: 2),
            ];
          },
    );

    final result = await repo.list();

    expect(capturedTable, 'categories');
    expect(capturedOrder, 'sort_order');
    expect(result, isA<Success<List<Category>>>());
    final categories = (result as Success<List<Category>>).data;
    expect(categories.map((c) => c.slug), ['shoes', 'rackets']);
    expect(categories.map((c) => c.sortOrder), [1, 2]);
  });

  test('PostgrestException becomes DatabaseException with code', () async {
    final repo = SupabaseCategoryRepository.testing(
      fetchSingle:
          ({
            required String table,
            required String filterColumn,
            required String filterValue,
          }) async {
            throw const PostgrestException(
              message: 'missing category',
              code: 'PGRST116',
            );
          },
      fetchOrderedList:
          ({required String table, required String orderColumn}) async {
            throw const PostgrestException(
              message: 'list failed',
              code: '42P01',
            );
          },
    );

    final byId = await repo.getById(_categoryId);
    expect(byId, isA<Failure<Category>>());
    final byIdError = (byId as Failure<Category>).error;
    expect(byIdError, isA<DatabaseException>());
    expect((byIdError as DatabaseException).code, 'PGRST116');

    final bySlug = await repo.getBySlug('missing');
    expect(bySlug, isA<Failure<Category>>());
    expect(
      ((bySlug as Failure<Category>).error as DatabaseException).code,
      'PGRST116',
    );

    final list = await repo.list();
    expect(list, isA<Failure<List<Category>>>());
    expect(
      ((list as Failure<List<Category>>).error as DatabaseException).code,
      '42P01',
    );
  });
}

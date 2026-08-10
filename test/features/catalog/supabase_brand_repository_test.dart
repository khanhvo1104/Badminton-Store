import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/catalog/data/repositories/supabase_brand_repository.dart';
import 'package:base_project/features/catalog/domain/entities/brand.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _brandId = '10000000-0000-4000-8000-000000000001';

Map<String, dynamic> _brandRow({
  String id = _brandId,
  String name = 'Yonex',
  String slug = 'yonex',
  String? description = 'Japanese badminton brand',
  String? logoPath = 'brands/yonex.png',
  String? websiteUrl = 'https://yonex.com',
  String? countryOfOrigin = 'JP',
  int sortOrder = 1,
  bool isActive = true,
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'slug': slug,
    'description': description,
    'logo_path': logoPath,
    'website_url': websiteUrl,
    'country_of_origin': countryOfOrigin,
    'sort_order': sortOrder,
    'is_active': isActive,
  };
}

void main() {
  test('getById targets brands.id and maps all fields', () async {
    late String capturedTable;
    late String capturedColumn;
    late String capturedValue;

    final repo = SupabaseBrandRepository.testing(
      fetchSingle:
          ({
            required String table,
            required String filterColumn,
            required String filterValue,
          }) async {
            capturedTable = table;
            capturedColumn = filterColumn;
            capturedValue = filterValue;
            return _brandRow();
          },
      fetchOrderedList:
          ({required String table, required String orderColumn}) async =>
              const [],
    );

    final result = await repo.getById(_brandId);

    expect(capturedTable, 'brands');
    expect(capturedColumn, 'id');
    expect(capturedValue, _brandId);
    expect(result, isA<Success<Brand>>());
    final brand = (result as Success<Brand>).data;
    expect(brand.id, _brandId);
    expect(brand.name, 'Yonex');
    expect(brand.slug, 'yonex');
    expect(brand.description, 'Japanese badminton brand');
    expect(brand.logoPath, 'brands/yonex.png');
    expect(brand.websiteUrl, 'https://yonex.com');
    expect(brand.countryOfOrigin, 'JP');
    expect(brand.sortOrder, 1);
    expect(brand.isActive, isTrue);
  });

  test('getById maps optional nulls and is_active fallback', () async {
    final repo = SupabaseBrandRepository.testing(
      fetchSingle:
          ({
            required String table,
            required String filterColumn,
            required String filterValue,
          }) async {
            return _brandRow(
              description: null,
              logoPath: null,
              websiteUrl: null,
              countryOfOrigin: null,
            )..remove('is_active');
          },
      fetchOrderedList:
          ({required String table, required String orderColumn}) async =>
              const [],
    );

    final brand = ((await repo.getById(_brandId)) as Success<Brand>).data;
    expect(brand.description, isNull);
    expect(brand.logoPath, isNull);
    expect(brand.websiteUrl, isNull);
    expect(brand.countryOfOrigin, isNull);
    expect(brand.isActive, isTrue);
  });

  test('list targets brands ordered by sort_order', () async {
    late String capturedTable;
    late String capturedOrder;

    final repo = SupabaseBrandRepository.testing(
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
              _brandRow(
                id: '10000000-0000-4000-8000-000000000002',
                name: 'Lining',
                slug: 'lining',
                sortOrder: 1,
              ),
              _brandRow(sortOrder: 2),
            ];
          },
    );

    final result = await repo.list();

    expect(capturedTable, 'brands');
    expect(capturedOrder, 'sort_order');
    expect(result, isA<Success<List<Brand>>>());
    final brands = (result as Success<List<Brand>>).data;
    expect(brands.map((b) => b.slug), ['lining', 'yonex']);
    expect(brands.map((b) => b.sortOrder), [1, 2]);
  });

  test('PostgrestException becomes DatabaseException with code', () async {
    final repo = SupabaseBrandRepository.testing(
      fetchSingle:
          ({
            required String table,
            required String filterColumn,
            required String filterValue,
          }) async {
            throw const PostgrestException(
              message: 'not found',
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

    final byId = await repo.getById(_brandId);
    expect(byId, isA<Failure<Brand>>());
    final byIdError = (byId as Failure<Brand>).error;
    expect(byIdError, isA<DatabaseException>());
    expect((byIdError as DatabaseException).code, 'PGRST116');
    expect(byIdError.message, 'not found');

    final list = await repo.list();
    expect(list, isA<Failure<List<Brand>>>());
    final listError = (list as Failure<List<Brand>>).error;
    expect(listError, isA<DatabaseException>());
    expect((listError as DatabaseException).code, '42P01');
  });
}

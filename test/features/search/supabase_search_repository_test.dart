import 'dart:convert';

import 'package:base_project/core/constants/storage_keys.dart';
import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/core/storage/preferences_service.dart';
import 'package:base_project/features/product/data/supabase_product_mapper.dart';
import 'package:base_project/features/product/domain/entities/product.dart';
import 'package:base_project/features/search/data/repositories/supabase_search_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _productId = '30000000-0000-4000-8000-000000000001';
const _categoryId = '20000000-0000-4000-8000-000000000001';
const _brandId = '10000000-0000-4000-8000-000000000001';

const _forbiddenParamKeys = <String>{
  'user_id',
  'p_user_id',
  'role',
  'p_role',
  'total',
  'p_total',
  'page',
  'p_page',
  'offset',
  'p_offset',
  'limit',
  'query',
  'p_q',
};

Map<String, dynamic> _catalogRow({
  String id = _productId,
  String name = 'Astrox 88 D',
  String slug = 'astrox-88-d',
  String? shortDescription = 'Head-heavy racket',
  String categoryId = _categoryId,
  String? brandId = _brandId,
  String? primaryImagePath = 'products/astrox.png',
  double minPrice = 1890000,
  double? minCompareAtPrice = 2190000,
  bool isFeatured = true,
  bool hasStock = true,
  String? publishedAt = '2026-01-15T00:00:00.000Z',
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'slug': slug,
    'short_description': shortDescription,
    'category_id': categoryId,
    'brand_id': brandId,
    'primary_image_path': primaryImagePath,
    'min_price': minPrice,
    'min_compare_at_price': minCompareAtPrice,
    'is_featured': isFeatured,
    'has_stock': hasStock,
    'published_at': publishedAt,
  };
}

SupabaseSearchRepository _repo({
  required FakePreferencesService preferences,
  required SearchProductsRpc rpc,
}) {
  return SupabaseSearchRepository.testing(preferences: preferences, rpc: rpc);
}

void main() {
  test(
    'search calls search_products with exactly p_query and p_limit',
    () async {
      late String capturedName;
      late Map<String, Object?> capturedParams;
      final preferences = FakePreferencesService();

      final repo = _repo(
        preferences: preferences,
        rpc:
            ({
              required String functionName,
              required Map<String, Object?> params,
            }) async {
              capturedName = functionName;
              capturedParams = Map<String, Object?>.from(params);
              return const <dynamic>[];
            },
      );

      final result = await repo.search(query: 'yonex', page: 3, pageSize: 12);

      expect(result, isA<Success<List<Product>>>());
      expect(capturedName, 'search_products');
      expect(capturedParams.keys.toSet(), {'p_query', 'p_limit'});
      expect(capturedParams['p_query'], 'yonex');
      expect(capturedParams['p_limit'], 12);
      for (final key in _forbiddenParamKeys) {
        expect(capturedParams.containsKey(key), isFalse, reason: key);
      }
    },
  );

  test('search maps rows through productFromCatalogRow', () async {
    final preferences = FakePreferencesService();
    final row = _catalogRow();
    final expected = productFromCatalogRow(row);

    final repo = _repo(
      preferences: preferences,
      rpc:
          ({
            required String functionName,
            required Map<String, Object?> params,
          }) async => [row],
    );

    final result = await repo.search(query: 'astrox');
    expect(result, isA<Success<List<Product>>>());
    final products = (result as Success<List<Product>>).data;
    expect(products, hasLength(1));
    expect(products.single, expected);
    expect(products.single.id, _productId);
    expect(products.single.name, 'Astrox 88 D');
    expect(products.single.brandId, _brandId);
    expect(products.single.images.single.storagePath, 'products/astrox.png');
    expect(products.single.variants.single.price, 1890000);
    expect(products.single.variants.single.compareAtPrice, 2190000);
  });

  test('PostgrestException becomes DatabaseException with code', () async {
    final preferences = FakePreferencesService();
    final repo = _repo(
      preferences: preferences,
      rpc:
          ({
            required String functionName,
            required Map<String, Object?> params,
          }) async {
            throw const PostgrestException(
              message: 'rpc failed',
              code: '42883',
            );
          },
    );

    final result = await repo.search(query: 'fail');
    expect(result, isA<Failure<List<Product>>>());
    final error = (result as Failure<List<Product>>).error;
    expect(error, isA<DatabaseException>());
    expect((error as DatabaseException).code, '42883');
    expect(error.message, 'rpc failed');
  });

  test('recentQueries returns empty for missing and empty storage', () async {
    final preferences = FakePreferencesService();
    final repo = _repo(
      preferences: preferences,
      rpc:
          ({
            required String functionName,
            required Map<String, Object?> params,
          }) async => const [],
    );

    expect(
      ((await repo.recentQueries()) as Success<List<String>>).data,
      isEmpty,
    );

    await preferences.setString(StorageKeys.recentSearches, '');
    expect(
      ((await repo.recentQueries()) as Success<List<String>>).data,
      isEmpty,
    );
  });

  test('malformed and non-list recent search JSON return empty list', () async {
    final preferences = FakePreferencesService();
    final repo = _repo(
      preferences: preferences,
      rpc:
          ({
            required String functionName,
            required Map<String, Object?> params,
          }) async => const [],
    );

    await preferences.setString(StorageKeys.recentSearches, '{not-json');
    expect(
      ((await repo.recentQueries()) as Success<List<String>>).data,
      isEmpty,
    );

    await preferences.setString(
      StorageKeys.recentSearches,
      jsonEncode({'query': 'yonex'}),
    );
    expect(
      ((await repo.recentQueries()) as Success<List<String>>).data,
      isEmpty,
    );

    await preferences.setString(StorageKeys.recentSearches, '"just-a-string"');
    expect(
      ((await repo.recentQueries()) as Success<List<String>>).data,
      isEmpty,
    );
  });

  test(
    'successful search trims, dedupes case-insensitively, and caps at eight',
    () async {
      final preferences = FakePreferencesService();
      final repo = _repo(
        preferences: preferences,
        rpc:
            ({
              required String functionName,
              required Map<String, Object?> params,
            }) async => const [],
      );

      await repo.search(query: '  Alpha  ');
      await repo.search(query: 'beta');
      await repo.search(query: 'ALPHA');
      await repo.search(query: 'gamma');
      await repo.search(query: 'delta');
      await repo.search(query: 'epsilon');
      await repo.search(query: 'zeta');
      await repo.search(query: 'eta');
      await repo.search(query: 'theta');
      await repo.search(query: 'iota');

      final recent =
          ((await repo.recentQueries()) as Success<List<String>>).data;
      expect(recent, hasLength(8));
      expect(recent.first, 'iota');
      expect(recent.contains('Alpha'), isFalse);
      expect(recent.contains('ALPHA'), isTrue);
      expect(recent, [
        'iota',
        'theta',
        'eta',
        'zeta',
        'epsilon',
        'delta',
        'gamma',
        'ALPHA',
      ]);
    },
  );

  test('blank and whitespace queries are not remembered', () async {
    final preferences = FakePreferencesService();
    final repo = _repo(
      preferences: preferences,
      rpc:
          ({
            required String functionName,
            required Map<String, Object?> params,
          }) async => const [],
    );

    await repo.search(query: 'kept');
    await repo.search(query: '');
    await repo.search(query: '   ');

    final recent = ((await repo.recentQueries()) as Success<List<String>>).data;
    expect(recent, ['kept']);
  });

  test('clearRecentQueries removes stored queries', () async {
    final preferences = FakePreferencesService();
    final repo = _repo(
      preferences: preferences,
      rpc:
          ({
            required String functionName,
            required Map<String, Object?> params,
          }) async => const [],
    );

    await repo.search(query: 'yonex');
    expect(((await repo.recentQueries()) as Success<List<String>>).data, [
      'yonex',
    ]);

    final cleared = await repo.clearRecentQueries();
    expect(cleared, isA<Success<void>>());
    expect(
      ((await repo.recentQueries()) as Success<List<String>>).data,
      isEmpty,
    );
    expect(await preferences.getString(StorageKeys.recentSearches), isNull);
  });
}

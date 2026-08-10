import 'dart:convert';

import 'package:base_project/core/constants/storage_keys.dart';
import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/core/storage/preferences_service.dart';
import 'package:base_project/features/product/data/supabase_product_mapper.dart';
import 'package:base_project/features/product/domain/entities/product.dart';
import 'package:base_project/features/search/domain/repositories/search_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseSearchRepository implements SearchRepository {
  SupabaseSearchRepository(this._client, this._preferences);

  final SupabaseClient _client;
  final PreferencesService _preferences;

  @override
  Future<Result<void>> clearRecentQueries() async {
    await _preferences.remove(StorageKeys.recentSearches);
    return const Success(null);
  }

  @override
  Future<Result<List<String>>> recentQueries() async {
    final raw = await _preferences.getString(StorageKeys.recentSearches);
    if (raw == null || raw.isEmpty) {
      return const Success(<String>[]);
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const Success(<String>[]);
    }
    return Success(
      decoded.map((item) => item.toString()).toList(growable: false),
    );
  }

  @override
  Future<Result<List<Product>>> search({
    required String query,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final rows = await _client.rpc<List<dynamic>>(
        'search_products',
        params: {'p_query': query, 'p_limit': pageSize},
      );
      await _rememberQuery(query);
      return Success(
        rows
            .map(
              (row) =>
                  productFromCatalogRow(Map<String, dynamic>.from(row as Map)),
            )
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

  Future<void> _rememberQuery(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final current = await recentQueries();
    final base = current.when(
      success: (data) => data,
      failure: (_) => const <String>[],
    );
    final merged = <String>[
      trimmed,
      ...base.where((item) => item.toLowerCase() != trimmed.toLowerCase()),
    ].take(8).toList(growable: false);
    await _preferences.setString(
      StorageKeys.recentSearches,
      jsonEncode(merged),
    );
  }
}

import 'package:base_project/features/home/data/data_sources/home_remote_data_source.dart';
import 'package:base_project/features/home/data/models/dashboard_item_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseHomeRemoteDataSource implements HomeRemoteDataSource {
  SupabaseHomeRemoteDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<List<DashboardItemModel>> fetchDashboardItems() async {
    final rows = await _client
        .from('product_catalog')
        .select('id, name, short_description, category_name')
        .eq('is_featured', true)
        .order('published_at', ascending: false)
        .limit(4);

    return rows
        .map((row) {
          final map = Map<String, dynamic>.from(row);
          return DashboardItemModel(
            id: map['id'].toString(),
            title: map['name'].toString(),
            subtitle: (map['short_description'] ?? map['category_name'] ?? '')
                .toString(),
            iconName: _iconNameForCategory(map['category_name']?.toString()),
          );
        })
        .toList(growable: false);
  }

  String _iconNameForCategory(String? categoryName) {
    if (categoryName == null) {
      return 'dashboard';
    }
    final lower = categoryName.toLowerCase();
    if (lower.contains('vợt')) {
      return 'sports';
    }
    if (lower.contains('giày')) {
      return 'footwear';
    }
    if (lower.contains('cầu')) {
      return 'inventory';
    }
    return 'dashboard';
  }
}

import 'package:base_project/features/product/data/repositories/supabase_product_repository.dart';
import 'package:base_project/features/product/data/supabase_product_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

const _safeVariantSelectColumns = <String>[
  'id',
  'product_id',
  'sku',
  'name',
  'color_name',
  'color_hex',
  'racket_weight_class',
  'grip_size',
  'shoe_size',
  'clothing_size',
  'unit',
  'price',
  'compare_at_price',
  'attributes',
  'is_default',
  'is_active',
  'sort_order',
];

void main() {
  test(
    'product variant select projection includes mapper fields and excludes cost_price',
    () {
      expect(supabaseProductVariantSelect, isNot(contains('*')));
      expect(supabaseProductVariantSelect, isNot(contains('cost_price')));
      expect(supabaseProductVariantSelect, isNot(contains('barcode')));
      expect(supabaseProductVariantSelect, isNot(contains('created_at')));
      expect(supabaseProductVariantSelect, isNot(contains('updated_at')));

      final selected = supabaseProductVariantSelect
          .split(',')
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toSet();
      expect(selected, unorderedEquals(_safeVariantSelectColumns));
    },
  );

  test(
    'safe variant projection maps through productVariantFromRow for detail UI',
    () {
      final variant = productVariantFromRow({
        'id': '40000000-0000-4000-8000-000000000001',
        'product_id': '30000000-0000-4000-8000-000000000001',
        'sku': 'RKT-YON-AS88-RED-3U-G5',
        'name': '3U / G5 Đỏ',
        'color_name': 'Đỏ',
        'color_hex': '#C62828',
        'racket_weight_class': '3U',
        'grip_size': 'G5',
        'shoe_size': null,
        'clothing_size': null,
        'unit': 'item',
        'price': 1890000,
        'compare_at_price': 2190000,
        'attributes': <String, Object?>{},
        'is_default': true,
        'is_active': true,
        'sort_order': 1,
      }, availableQuantity: 3);

      expect(variant.sku, 'RKT-YON-AS88-RED-3U-G5');
      expect(variant.price, 1890000);
      expect(variant.compareAtPrice, 2190000);
      expect(variant.availableQuantity, 3);
      expect(variant.isDefault, isTrue);
    },
  );
}

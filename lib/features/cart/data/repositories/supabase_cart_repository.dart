import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/core/supabase/supabase_row.dart';
import 'package:base_project/features/cart/domain/entities/cart.dart';
import 'package:base_project/features/cart/domain/entities/cart_item.dart';
import 'package:base_project/features/cart/domain/repositories/cart_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseCartRepository implements CartRepository {
  SupabaseCartRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<Cart>> addItem({
    required String productId,
    required String variantId,
    required int quantity,
  }) async {
    try {
      final cartId = await _ensureActiveCart();
      final existing = await _client
          .from('cart_items')
          .select()
          .eq('cart_id', cartId)
          .eq('variant_id', variantId)
          .maybeSingle();
      if (existing != null) {
        final current = Map<String, dynamic>.from(existing);
        await _client
            .from('cart_items')
            .update({'quantity': requireInt(current, 'quantity') + quantity})
            .eq('id', requireString(current, 'id'));
      } else {
        await _client.from('cart_items').insert({
          'cart_id': cartId,
          'variant_id': variantId,
          'quantity': quantity,
        });
      }
      return getCart();
    } on PostgrestException catch (error, stackTrace) {
      return Failure(
        DatabaseException(
          error.message,
          code: error.code,
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } on AppException catch (error) {
      return Failure(error);
    }
  }

  @override
  Future<Result<void>> clear() async {
    try {
      final cartId = await _ensureActiveCart();
      await _client.from('cart_items').delete().eq('cart_id', cartId);
      return const Success(null);
    } on PostgrestException catch (error, stackTrace) {
      return Failure(
        DatabaseException(
          error.message,
          code: error.code,
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } on AppException catch (error) {
      return Failure(error);
    }
  }

  @override
  Future<Result<Cart>> getCart() async {
    try {
      final cartId = await _ensureActiveCart();
      final cartRow = await _client.from('carts').select().eq('id', cartId).single();
      final itemRows = await _client
          .from('cart_items')
          .select()
          .eq('cart_id', cartId)
          .order('created_at');
      final items = await _mapItems(
        itemRows.map((row) => Map<String, dynamic>.from(row)).toList(),
      );
      final map = Map<String, dynamic>.from(cartRow);
      return Success(
        Cart(
          id: requireString(map, 'id'),
          userId: optionalString(map, 'user_id'),
          guestToken: optionalString(map, 'guest_token'),
          status: requireString(map, 'status'),
          currencyCode: requireString(map, 'currency_code'),
          items: items,
          expiresAt: optionalDateTime(map, 'expires_at'),
          updatedAt: optionalDateTime(map, 'updated_at'),
        ),
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
    } on AppException catch (error) {
      return Failure(error);
    }
  }

  @override
  Future<Result<Cart>> removeItem(String itemId) async {
    try {
      await _client.from('cart_items').delete().eq('id', itemId);
      return getCart();
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
  Future<Result<Cart>> updateQuantity({
    required String itemId,
    required int quantity,
  }) async {
    try {
      if (quantity <= 0) {
        await _client.from('cart_items').delete().eq('id', itemId);
      } else {
        await _client
            .from('cart_items')
            .update({'quantity': quantity})
            .eq('id', itemId);
      }
      return getCart();
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

  Future<String> _ensureActiveCart() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const UnauthorizedException('Please sign in to use the cart');
    }

    final existing = await _client
        .from('carts')
        .select()
        .eq('user_id', userId)
        .eq('status', 'active')
        .maybeSingle();
    if (existing != null) {
      return Map<String, dynamic>.from(existing)['id'].toString();
    }

    final inserted = await _client
        .from('carts')
        .insert({'user_id': userId, 'status': 'active', 'currency_code': 'VND'})
        .select()
        .single();
    return Map<String, dynamic>.from(inserted)['id'].toString();
  }

  Future<List<CartItem>> _mapItems(List<SupabaseRow> itemRows) async {
    if (itemRows.isEmpty) {
      return const [];
    }

    final variantIds = itemRows.map((row) => requireString(row, 'variant_id')).toSet();
    final variantRows = await _client
        .from('product_variants')
        .select('id, product_id, name, sku, price, color_name, racket_weight_class, grip_size, shoe_size, clothing_size')
        .inFilter('id', variantIds.toList());
    final variantById = {
      for (final row in variantRows)
        Map<String, dynamic>.from(row)['id'].toString(): Map<String, dynamic>.from(row),
    };

    final productIds = variantById.values
        .map((row) => row['product_id'].toString())
        .toSet()
        .toList();
    final productRows = productIds.isEmpty
        ? const <dynamic>[]
        : await _client
              .from('products')
              .select('id, name')
              .inFilter('id', productIds);
    final productById = {
      for (final row in productRows)
        Map<String, dynamic>.from(row as Map)['id'].toString():
            Map<String, dynamic>.from(row),
    };

    final imageRows = productIds.isEmpty
        ? const <dynamic>[]
        : await _client
              .from('product_images')
              .select('product_id, storage_path, is_primary')
              .inFilter('product_id', productIds)
              .isFilter('variant_id', null);
    final imageByProductId = <String, String>{};
    for (final row in imageRows) {
      final map = Map<String, dynamic>.from(row as Map);
      final productId = map['product_id'].toString();
      imageByProductId.putIfAbsent(
        productId,
        () => map['storage_path'].toString(),
      );
    }

    return itemRows.map((row) {
      final variant = variantById[requireString(row, 'variant_id')];
      final product = variant == null
          ? null
          : productById[variant['product_id'].toString()];
      final productId = variant?['product_id']?.toString();
      return CartItem(
        id: requireString(row, 'id'),
        cartId: requireString(row, 'cart_id'),
        variantId: requireString(row, 'variant_id'),
        quantity: requireInt(row, 'quantity'),
        unitPriceSnapshot: row['unit_price_snapshot'] == null
            ? (variant == null
                  ? null
                  : requireDouble(variant, 'price'))
            : requireDouble(row, 'unit_price_snapshot'),
        productId: productId,
        productName: product?['name']?.toString(),
        variantLabel: variant == null ? null : _variantLabel(variant),
        imagePath: productId == null ? null : imageByProductId[productId],
      );
    }).toList(growable: false);
  }

  String _variantLabel(SupabaseRow row) {
    final parts = <String>[
      if (optionalString(row, 'name') case final name?) name,
      if (optionalString(row, 'color_name') case final color?) color,
      if (optionalString(row, 'racket_weight_class') case final weight?) weight,
      if (optionalString(row, 'grip_size') case final grip?) grip,
      if (optionalString(row, 'shoe_size') case final shoe?) shoe,
      if (optionalString(row, 'clothing_size') case final clothing?) clothing,
    ];
    return parts.join(' • ');
  }
}

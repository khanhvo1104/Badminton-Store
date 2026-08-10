import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/core/supabase/supabase_row.dart';
import 'package:base_project/features/cart/domain/entities/cart.dart';
import 'package:base_project/features/cart/domain/entities/cart_item.dart';
import 'package:base_project/features/cart/domain/repositories/cart_repository.dart';
import 'package:meta/meta.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Safe variant columns used for cart-item enrichment (excludes `cost_price`).
@visibleForTesting
const supabaseCartVariantSelect =
    'id, product_id, name, sku, price, color_name, racket_weight_class, grip_size, shoe_size, clothing_size';

@visibleForTesting
const supabaseCartProductSelect = 'id, name';

@visibleForTesting
const supabaseCartProductImageSelect = 'product_id, storage_path, is_primary';

/// Looks up the authenticated user's active cart row.
@visibleForTesting
typedef CartFindActiveQuery =
    Future<Map<String, dynamic>?> Function({
      required String table,
      required String userId,
      required String status,
    });

/// Inserts a cart row and returns the selected result.
@visibleForTesting
typedef CartInsertQuery =
    Future<Map<String, dynamic>> Function({
      required String table,
      required Map<String, Object?> values,
    });

/// Fetches a single cart row by id.
@visibleForTesting
typedef CartFetchByIdQuery =
    Future<Map<String, dynamic>> Function({
      required String table,
      required String cartId,
    });

/// Lists cart item rows for a cart with a single order column.
@visibleForTesting
typedef CartItemsListQuery =
    Future<List<Map<String, dynamic>>> Function({
      required String table,
      required String cartId,
      required String orderColumn,
    });

/// Finds a cart item by cart + variant.
@visibleForTesting
typedef CartItemFindByVariantQuery =
    Future<Map<String, dynamic>?> Function({
      required String table,
      required String cartId,
      required String variantId,
    });

/// Updates a cart item quantity by item id.
@visibleForTesting
typedef CartItemUpdateQuantityQuery =
    Future<void> Function({
      required String table,
      required String itemId,
      required int quantity,
    });

/// Inserts a cart item row.
@visibleForTesting
typedef CartItemInsertQuery =
    Future<void> Function({
      required String table,
      required Map<String, Object?> values,
    });

/// Deletes a cart item by id.
@visibleForTesting
typedef CartItemDeleteByIdQuery =
    Future<void> Function({required String table, required String itemId});

/// Deletes all cart items for a cart.
@visibleForTesting
typedef CartItemsDeleteByCartQuery =
    Future<void> Function({required String table, required String cartId});

/// Fetches rows by id list with an explicit select projection.
@visibleForTesting
typedef CartRowsByIdsQuery =
    Future<List<Map<String, dynamic>>> Function({
      required String table,
      required String selectColumns,
      required List<String> ids,
    });

/// Fetches product-level images for the given product ids.
@visibleForTesting
typedef CartProductImagesQuery =
    Future<List<Map<String, dynamic>>> Function({
      required String table,
      required String selectColumns,
      required List<String> productIds,
    });

final class SupabaseCartRepository implements CartRepository {
  SupabaseCartRepository(SupabaseClient client)
    : _currentUserId = (() => client.auth.currentUser?.id),
      _findActiveCart =
          (({
            required String table,
            required String userId,
            required String status,
          }) async {
            final row = await client
                .from(table)
                .select()
                .eq('user_id', userId)
                .eq('status', status)
                .maybeSingle();
            return row == null ? null : Map<String, dynamic>.from(row);
          }),
      _insertCart =
          (({
            required String table,
            required Map<String, Object?> values,
          }) async {
            final row = await client
                .from(table)
                .insert(values)
                .select()
                .single();
            return Map<String, dynamic>.from(row);
          }),
      _fetchCartById =
          (({required String table, required String cartId}) async {
            final row = await client
                .from(table)
                .select()
                .eq('id', cartId)
                .single();
            return Map<String, dynamic>.from(row);
          }),
      _listCartItems =
          (({
            required String table,
            required String cartId,
            required String orderColumn,
          }) async {
            final rows = await client
                .from(table)
                .select()
                .eq('cart_id', cartId)
                .order(orderColumn);
            return rows
                .map((row) => Map<String, dynamic>.from(row))
                .toList(growable: false);
          }),
      _findCartItemByVariant =
          (({
            required String table,
            required String cartId,
            required String variantId,
          }) async {
            final row = await client
                .from(table)
                .select()
                .eq('cart_id', cartId)
                .eq('variant_id', variantId)
                .maybeSingle();
            return row == null ? null : Map<String, dynamic>.from(row);
          }),
      _updateCartItemQuantity =
          (({
            required String table,
            required String itemId,
            required int quantity,
          }) async {
            await client
                .from(table)
                .update({'quantity': quantity})
                .eq('id', itemId);
          }),
      _insertCartItem =
          (({
            required String table,
            required Map<String, Object?> values,
          }) async {
            await client.from(table).insert(values);
          }),
      _deleteCartItemById =
          (({required String table, required String itemId}) async {
            await client.from(table).delete().eq('id', itemId);
          }),
      _deleteCartItemsByCart =
          (({required String table, required String cartId}) async {
            await client.from(table).delete().eq('cart_id', cartId);
          }),
      _fetchVariantsByIds =
          (({
            required String table,
            required String selectColumns,
            required List<String> ids,
          }) async {
            final rows = await client
                .from(table)
                .select(selectColumns)
                .inFilter('id', ids);
            return rows
                .map((row) => Map<String, dynamic>.from(row))
                .toList(growable: false);
          }),
      _fetchProductsByIds =
          (({
            required String table,
            required String selectColumns,
            required List<String> ids,
          }) async {
            final rows = await client
                .from(table)
                .select(selectColumns)
                .inFilter('id', ids);
            return rows
                .map((row) => Map<String, dynamic>.from(row))
                .toList(growable: false);
          }),
      _fetchProductImages =
          (({
            required String table,
            required String selectColumns,
            required List<String> productIds,
          }) async {
            final rows = await client
                .from(table)
                .select(selectColumns)
                .inFilter('product_id', productIds)
                .isFilter('variant_id', null);
            return rows
                .map((row) => Map<String, dynamic>.from(row))
                .toList(growable: false);
          });

  @visibleForTesting
  SupabaseCartRepository.testing({
    required String? Function() currentUserId,
    required CartFindActiveQuery findActiveCart,
    required CartInsertQuery insertCart,
    required CartFetchByIdQuery fetchCartById,
    required CartItemsListQuery listCartItems,
    required CartItemFindByVariantQuery findCartItemByVariant,
    required CartItemUpdateQuantityQuery updateCartItemQuantity,
    required CartItemInsertQuery insertCartItem,
    required CartItemDeleteByIdQuery deleteCartItemById,
    required CartItemsDeleteByCartQuery deleteCartItemsByCart,
    required CartRowsByIdsQuery fetchVariantsByIds,
    required CartRowsByIdsQuery fetchProductsByIds,
    required CartProductImagesQuery fetchProductImages,
  }) : _currentUserId = currentUserId,
       _findActiveCart = findActiveCart,
       _insertCart = insertCart,
       _fetchCartById = fetchCartById,
       _listCartItems = listCartItems,
       _findCartItemByVariant = findCartItemByVariant,
       _updateCartItemQuantity = updateCartItemQuantity,
       _insertCartItem = insertCartItem,
       _deleteCartItemById = deleteCartItemById,
       _deleteCartItemsByCart = deleteCartItemsByCart,
       _fetchVariantsByIds = fetchVariantsByIds,
       _fetchProductsByIds = fetchProductsByIds,
       _fetchProductImages = fetchProductImages;

  final String? Function() _currentUserId;
  final CartFindActiveQuery _findActiveCart;
  final CartInsertQuery _insertCart;
  final CartFetchByIdQuery _fetchCartById;
  final CartItemsListQuery _listCartItems;
  final CartItemFindByVariantQuery _findCartItemByVariant;
  final CartItemUpdateQuantityQuery _updateCartItemQuantity;
  final CartItemInsertQuery _insertCartItem;
  final CartItemDeleteByIdQuery _deleteCartItemById;
  final CartItemsDeleteByCartQuery _deleteCartItemsByCart;
  final CartRowsByIdsQuery _fetchVariantsByIds;
  final CartRowsByIdsQuery _fetchProductsByIds;
  final CartProductImagesQuery _fetchProductImages;

  @override
  Future<Result<Cart>> addItem({
    required String productId,
    required String variantId,
    required int quantity,
  }) async {
    try {
      final cartId = await _ensureActiveCart();
      final existing = await _findCartItemByVariant(
        table: 'cart_items',
        cartId: cartId,
        variantId: variantId,
      );
      if (existing != null) {
        await _updateCartItemQuantity(
          table: 'cart_items',
          itemId: requireString(existing, 'id'),
          quantity: requireInt(existing, 'quantity') + quantity,
        );
      } else {
        await _insertCartItem(
          table: 'cart_items',
          values: {
            'cart_id': cartId,
            'variant_id': variantId,
            'quantity': quantity,
          },
        );
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
      await _deleteCartItemsByCart(table: 'cart_items', cartId: cartId);
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
      final cartRow = await _fetchCartById(table: 'carts', cartId: cartId);
      final itemRows = await _listCartItems(
        table: 'cart_items',
        cartId: cartId,
        orderColumn: 'created_at',
      );
      final items = await _mapItems(itemRows);
      return Success(
        Cart(
          id: requireString(cartRow, 'id'),
          userId: optionalString(cartRow, 'user_id'),
          guestToken: optionalString(cartRow, 'guest_token'),
          status: requireString(cartRow, 'status'),
          currencyCode: requireString(cartRow, 'currency_code'),
          items: items,
          expiresAt: optionalDateTime(cartRow, 'expires_at'),
          updatedAt: optionalDateTime(cartRow, 'updated_at'),
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
      await _deleteCartItemById(table: 'cart_items', itemId: itemId);
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
        await _deleteCartItemById(table: 'cart_items', itemId: itemId);
      } else {
        await _updateCartItemQuantity(
          table: 'cart_items',
          itemId: itemId,
          quantity: quantity,
        );
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
    final userId = _currentUserId();
    if (userId == null) {
      throw const UnauthorizedException('Please sign in to use the cart');
    }

    final existing = await _findActiveCart(
      table: 'carts',
      userId: userId,
      status: 'active',
    );
    if (existing != null) {
      return existing['id'].toString();
    }

    final inserted = await _insertCart(
      table: 'carts',
      values: {'user_id': userId, 'status': 'active', 'currency_code': 'VND'},
    );
    return inserted['id'].toString();
  }

  Future<List<CartItem>> _mapItems(List<SupabaseRow> itemRows) async {
    if (itemRows.isEmpty) {
      return const [];
    }

    final variantIds = itemRows
        .map((row) => requireString(row, 'variant_id'))
        .toSet()
        .toList();
    final variantRows = await _fetchVariantsByIds(
      table: 'product_variants',
      selectColumns: supabaseCartVariantSelect,
      ids: variantIds,
    );
    final variantById = {
      for (final row in variantRows) row['id'].toString(): row,
    };

    final productIds = variantById.values
        .map((row) => row['product_id'].toString())
        .toSet()
        .toList();
    final productRows = productIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : await _fetchProductsByIds(
            table: 'products',
            selectColumns: supabaseCartProductSelect,
            ids: productIds,
          );
    final productById = {
      for (final row in productRows) row['id'].toString(): row,
    };

    final imageRows = productIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : await _fetchProductImages(
            table: 'product_images',
            selectColumns: supabaseCartProductImageSelect,
            productIds: productIds,
          );
    final imageByProductId = <String, String>{};
    for (final row in imageRows) {
      final productId = row['product_id'].toString();
      imageByProductId.putIfAbsent(
        productId,
        () => row['storage_path'].toString(),
      );
    }

    return itemRows
        .map((row) {
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
                ? (variant == null ? null : requireDouble(variant, 'price'))
                : requireDouble(row, 'unit_price_snapshot'),
            productId: productId,
            productName: product?['name']?.toString(),
            variantLabel: variant == null ? null : _variantLabel(variant),
            imagePath: productId == null ? null : imageByProductId[productId],
          );
        })
        .toList(growable: false);
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

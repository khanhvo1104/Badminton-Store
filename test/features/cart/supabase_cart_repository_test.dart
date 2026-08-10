import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/cart/data/repositories/supabase_cart_repository.dart';
import 'package:base_project/features/cart/domain/entities/cart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _userId = '11111111-1111-4111-8111-111111111111';
const _cartId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _itemId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const _variantId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const _productId = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
const _otherVariantId = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee';
const _otherProductId = 'ffffffff-ffff-4fff-8fff-ffffffffffff';
const _expiresAt = '2026-12-31T23:59:59.000Z';
const _updatedAt = '2026-08-10T12:00:00.000Z';

Never _unusedSeam() => throw StateError('database seam must not be invoked');

Map<String, dynamic> _cartRow({
  String id = _cartId,
  String? userId = _userId,
  String? guestToken,
  String status = 'active',
  String currencyCode = 'VND',
  String? expiresAt = _expiresAt,
  String? updatedAt = _updatedAt,
}) {
  return <String, dynamic>{
    'id': id,
    'user_id': userId,
    'guest_token': guestToken,
    'status': status,
    'currency_code': currencyCode,
    'expires_at': expiresAt,
    'updated_at': updatedAt,
  };
}

Map<String, dynamic> _cartItemRow({
  String id = _itemId,
  String cartId = _cartId,
  String variantId = _variantId,
  int quantity = 2,
  Object? unitPriceSnapshot = 150000,
}) {
  return <String, dynamic>{
    'id': id,
    'cart_id': cartId,
    'variant_id': variantId,
    'quantity': quantity,
    'unit_price_snapshot': unitPriceSnapshot,
  };
}

Map<String, dynamic> _variantRow({
  String id = _variantId,
  String productId = _productId,
  String name = '3U / G5',
  String sku = 'SKU-1',
  double price = 189000,
  String? colorName = 'Red',
  String? racketWeightClass = '3U',
  String? gripSize = 'G5',
  String? shoeSize,
  String? clothingSize,
}) {
  return <String, dynamic>{
    'id': id,
    'product_id': productId,
    'name': name,
    'sku': sku,
    'price': price,
    'color_name': colorName,
    'racket_weight_class': racketWeightClass,
    'grip_size': gripSize,
    'shoe_size': shoeSize,
    'clothing_size': clothingSize,
  };
}

SupabaseCartRepository _repo({
  String? Function()? currentUserId,
  CartFindActiveQuery? findActiveCart,
  CartInsertQuery? insertCart,
  CartFetchByIdQuery? fetchCartById,
  CartItemsListQuery? listCartItems,
  CartItemFindByVariantQuery? findCartItemByVariant,
  CartItemUpdateQuantityQuery? updateCartItemQuantity,
  CartItemInsertQuery? insertCartItem,
  CartItemDeleteByIdQuery? deleteCartItemById,
  CartItemsDeleteByCartQuery? deleteCartItemsByCart,
  CartRowsByIdsQuery? fetchVariantsByIds,
  CartRowsByIdsQuery? fetchProductsByIds,
  CartProductImagesQuery? fetchProductImages,
}) {
  return SupabaseCartRepository.testing(
    currentUserId: currentUserId ?? (() => _userId),
    findActiveCart:
        findActiveCart ??
        (({
          required String table,
          required String userId,
          required String status,
        }) async => _unusedSeam()),
    insertCart:
        insertCart ??
        (({
          required String table,
          required Map<String, Object?> values,
        }) async => _unusedSeam()),
    fetchCartById:
        fetchCartById ??
        (({required String table, required String cartId}) async =>
            _unusedSeam()),
    listCartItems:
        listCartItems ??
        (({
          required String table,
          required String cartId,
          required String orderColumn,
        }) async => _unusedSeam()),
    findCartItemByVariant:
        findCartItemByVariant ??
        (({
          required String table,
          required String cartId,
          required String variantId,
        }) async => _unusedSeam()),
    updateCartItemQuantity:
        updateCartItemQuantity ??
        (({
          required String table,
          required String itemId,
          required int quantity,
        }) async => _unusedSeam()),
    insertCartItem:
        insertCartItem ??
        (({
          required String table,
          required Map<String, Object?> values,
        }) async => _unusedSeam()),
    deleteCartItemById:
        deleteCartItemById ??
        (({required String table, required String itemId}) async =>
            _unusedSeam()),
    deleteCartItemsByCart:
        deleteCartItemsByCart ??
        (({required String table, required String cartId}) async =>
            _unusedSeam()),
    fetchVariantsByIds:
        fetchVariantsByIds ??
        (({
          required String table,
          required String selectColumns,
          required List<String> ids,
        }) async => _unusedSeam()),
    fetchProductsByIds:
        fetchProductsByIds ??
        (({
          required String table,
          required String selectColumns,
          required List<String> ids,
        }) async => _unusedSeam()),
    fetchProductImages:
        fetchProductImages ??
        (({
          required String table,
          required String selectColumns,
          required List<String> productIds,
        }) async => _unusedSeam()),
  );
}

/// Minimal seams needed to satisfy getCart after a mutation.
SupabaseCartRepository _repoWithLoadedCart({
  String? Function()? currentUserId,
  CartFindActiveQuery? findActiveCart,
  CartInsertQuery? insertCart,
  CartItemFindByVariantQuery? findCartItemByVariant,
  CartItemUpdateQuantityQuery? updateCartItemQuantity,
  CartItemInsertQuery? insertCartItem,
  CartItemDeleteByIdQuery? deleteCartItemById,
  CartItemsDeleteByCartQuery? deleteCartItemsByCart,
  List<Map<String, dynamic>> itemRows = const [],
  List<Map<String, dynamic>> variantRows = const [],
  List<Map<String, dynamic>> productRows = const [],
  List<Map<String, dynamic>> imageRows = const [],
}) {
  return _repo(
    currentUserId: currentUserId,
    findActiveCart:
        findActiveCart ??
        (({
          required String table,
          required String userId,
          required String status,
        }) async => _cartRow()),
    insertCart: insertCart,
    fetchCartById: ({required String table, required String cartId}) async {
      expect(table, 'carts');
      expect(cartId, _cartId);
      return _cartRow()
        ..remove('expires_at')
        ..remove('updated_at')
        ..remove('guest_token');
    },
    listCartItems:
        ({
          required String table,
          required String cartId,
          required String orderColumn,
        }) async {
          expect(table, 'cart_items');
          expect(cartId, _cartId);
          expect(orderColumn, 'created_at');
          return itemRows;
        },
    findCartItemByVariant: findCartItemByVariant,
    updateCartItemQuantity: updateCartItemQuantity,
    insertCartItem: insertCartItem,
    deleteCartItemById: deleteCartItemById,
    deleteCartItemsByCart: deleteCartItemsByCart,
    fetchVariantsByIds:
        ({
          required String table,
          required String selectColumns,
          required List<String> ids,
        }) async {
          expect(table, 'product_variants');
          expect(selectColumns, supabaseCartVariantSelect);
          return variantRows
              .where((row) => ids.contains(row['id']))
              .toList(growable: false);
        },
    fetchProductsByIds:
        ({
          required String table,
          required String selectColumns,
          required List<String> ids,
        }) async {
          expect(table, 'products');
          expect(selectColumns, supabaseCartProductSelect);
          return productRows
              .where((row) => ids.contains(row['id']))
              .toList(growable: false);
        },
    fetchProductImages:
        ({
          required String table,
          required String selectColumns,
          required List<String> productIds,
        }) async {
          expect(table, 'product_images');
          expect(selectColumns, supabaseCartProductImageSelect);
          return imageRows
              .where((row) => productIds.contains(row['product_id']))
              .toList(growable: false);
        },
  );
}

void main() {
  group('variant select projection', () {
    test('excludes cost_price and wildcard', () {
      expect(supabaseCartVariantSelect, isNot(contains('*')));
      expect(supabaseCartVariantSelect, isNot(contains('cost_price')));
      expect(supabaseCartVariantSelect.split(', ').toSet(), {
        'id',
        'product_id',
        'name',
        'sku',
        'price',
        'color_name',
        'racket_weight_class',
        'grip_size',
        'shoe_size',
        'clothing_size',
      });
    });
  });

  group('unauthenticated boundary', () {
    test('getCart returns UnauthorizedException without DB seam', () async {
      var seamCalls = 0;
      final repo = _repo(
        currentUserId: () => null,
        findActiveCart:
            ({
              required String table,
              required String userId,
              required String status,
            }) async {
              seamCalls++;
              return _cartRow();
            },
      );

      final result = await repo.getCart();

      expect(seamCalls, 0);
      expect(result, isA<Failure<Cart>>());
      expect((result as Failure<Cart>).error, isA<UnauthorizedException>());
      expect(result.error.message, 'Please sign in to use the cart');
    });

    test('addItem returns UnauthorizedException without DB seam', () async {
      var seamCalls = 0;
      final repo = _repo(
        currentUserId: () => null,
        findActiveCart:
            ({
              required String table,
              required String userId,
              required String status,
            }) async {
              seamCalls++;
              return _cartRow();
            },
      );

      final result = await repo.addItem(
        productId: _productId,
        variantId: _variantId,
        quantity: 1,
      );

      expect(seamCalls, 0);
      expect(result, isA<Failure<Cart>>());
      expect((result as Failure<Cart>).error, isA<UnauthorizedException>());
    });

    test('clear returns UnauthorizedException without DB seam', () async {
      var seamCalls = 0;
      final repo = _repo(
        currentUserId: () => null,
        deleteCartItemsByCart:
            ({required String table, required String cartId}) async {
              seamCalls++;
            },
      );

      final result = await repo.clear();

      expect(seamCalls, 0);
      expect(result, isA<Failure<void>>());
      expect((result as Failure<void>).error, isA<UnauthorizedException>());
    });
  });

  group('active cart ensure', () {
    test(
      'lookup is scoped by authenticated user_id and active status',
      () async {
        late String capturedTable;
        late String capturedUserId;
        late String capturedStatus;

        final repo = _repoWithLoadedCart(
          findActiveCart:
              ({
                required String table,
                required String userId,
                required String status,
              }) async {
                capturedTable = table;
                capturedUserId = userId;
                capturedStatus = status;
                return _cartRow();
              },
        );

        final result = await repo.getCart();

        expect(capturedTable, 'carts');
        expect(capturedUserId, _userId);
        expect(capturedStatus, 'active');
        expect(result, isA<Success<Cart>>());
      },
    );

    test(
      'missing cart inserts owner id, active status, and VND only',
      () async {
        late String capturedTable;
        late Map<String, Object?> capturedValues;
        var findCalls = 0;

        final repo = _repoWithLoadedCart(
          findActiveCart:
              ({
                required String table,
                required String userId,
                required String status,
              }) async {
                findCalls++;
                return null;
              },
          insertCart:
              ({
                required String table,
                required Map<String, Object?> values,
              }) async {
                capturedTable = table;
                capturedValues = Map<String, Object?>.from(values);
                return _cartRow();
              },
        );

        final result = await repo.getCart();

        expect(findCalls, 1);
        expect(capturedTable, 'carts');
        expect(capturedValues.keys.toSet(), {
          'user_id',
          'status',
          'currency_code',
        });
        expect(capturedValues['user_id'], _userId);
        expect(capturedValues['status'], 'active');
        expect(capturedValues['currency_code'], 'VND');
        expect(result, isA<Success<Cart>>());
      },
    );
  });

  group('getCart', () {
    test(
      'loads resolved cart id, orders items, and maps optional fields',
      () async {
        late String cartTable;
        late String loadedCartId;
        late String itemsTable;
        late String itemsCartId;
        late String capturedOrderColumn;

        final repo = _repo(
          findActiveCart:
              ({
                required String table,
                required String userId,
                required String status,
              }) async => _cartRow(),
          fetchCartById:
              ({required String table, required String cartId}) async {
                cartTable = table;
                loadedCartId = cartId;
                return _cartRow(guestToken: 'guest-token');
              },
          listCartItems:
              ({
                required String table,
                required String cartId,
                required String orderColumn,
              }) async {
                itemsTable = table;
                itemsCartId = cartId;
                capturedOrderColumn = orderColumn;
                return const [];
              },
        );

        final result = await repo.getCart();

        expect(cartTable, 'carts');
        expect(loadedCartId, _cartId);
        expect(itemsTable, 'cart_items');
        expect(itemsCartId, _cartId);
        expect(capturedOrderColumn, 'created_at');
        expect(result, isA<Success<Cart>>());
        final cart = (result as Success<Cart>).data;
        expect(cart.id, _cartId);
        expect(cart.userId, _userId);
        expect(cart.guestToken, 'guest-token');
        expect(cart.status, 'active');
        expect(cart.currencyCode, 'VND');
        expect(cart.expiresAt, DateTime.parse(_expiresAt));
        expect(cart.updatedAt, DateTime.parse(_updatedAt));
        expect(cart.items, isEmpty);
      },
    );

    test('maps null optional timestamps and guest token', () async {
      final repo = _repo(
        findActiveCart:
            ({
              required String table,
              required String userId,
              required String status,
            }) async => _cartRow(),
        fetchCartById: ({required String table, required String cartId}) async {
          return _cartRow()
            ..['guest_token'] = null
            ..['expires_at'] = null
            ..['updated_at'] = null;
        },
        listCartItems:
            ({
              required String table,
              required String cartId,
              required String orderColumn,
            }) async => const [],
      );

      final cart = ((await repo.getCart()) as Success<Cart>).data;
      expect(cart.guestToken, isNull);
      expect(cart.expiresAt, isNull);
      expect(cart.updatedAt, isNull);
    });

    test('maps PostgrestException to DatabaseException with code', () async {
      final repo = _repo(
        findActiveCart:
            ({
              required String table,
              required String userId,
              required String status,
            }) async {
              throw const PostgrestException(
                message: 'cart lookup failed',
                code: '42501',
              );
            },
      );

      final result = await repo.getCart();

      expect(result, isA<Failure<Cart>>());
      final error = (result as Failure<Cart>).error;
      expect(error, isA<DatabaseException>());
      expect((error as DatabaseException).code, '42501');
      expect(error.message, 'cart lookup failed');
    });
  });

  group('item enrichment and mapping', () {
    test(
      'uses safe variant columns and limits product/image lookups to product ids',
      () async {
        late String variantSelect;
        late List<String> variantIds;
        late List<String> productIds;
        late List<String> imageProductIds;
        late String productSelect;
        late String imageSelect;

        final repo = _repo(
          findActiveCart:
              ({
                required String table,
                required String userId,
                required String status,
              }) async => _cartRow(),
          fetchCartById:
              ({required String table, required String cartId}) async =>
                  _cartRow(),
          listCartItems:
              ({
                required String table,
                required String cartId,
                required String orderColumn,
              }) async => [
                _cartItemRow(),
                _cartItemRow(
                  id: 'item-2',
                  variantId: _otherVariantId,
                  unitPriceSnapshot: null,
                  quantity: 1,
                ),
              ],
          fetchVariantsByIds:
              ({
                required String table,
                required String selectColumns,
                required List<String> ids,
              }) async {
                expect(table, 'product_variants');
                variantSelect = selectColumns;
                variantIds = List<String>.from(ids);
                return [
                  _variantRow(),
                  _variantRow(
                    id: _otherVariantId,
                    productId: _otherProductId,
                    name: '42',
                    colorName: null,
                    racketWeightClass: null,
                    gripSize: null,
                    shoeSize: '42',
                    clothingSize: null,
                    price: 99000,
                  ),
                ];
              },
          fetchProductsByIds:
              ({
                required String table,
                required String selectColumns,
                required List<String> ids,
              }) async {
                expect(table, 'products');
                productSelect = selectColumns;
                productIds = List<String>.from(ids)..sort();
                return [
                  {'id': _productId, 'name': 'Astrox 88'},
                  {'id': _otherProductId, 'name': 'Court Shoes'},
                ];
              },
          fetchProductImages:
              ({
                required String table,
                required String selectColumns,
                required List<String> productIds,
              }) async {
                expect(table, 'product_images');
                imageSelect = selectColumns;
                imageProductIds = List<String>.from(productIds)..sort();
                return [
                  {
                    'product_id': _productId,
                    'storage_path': 'products/astrox.png',
                    'is_primary': true,
                  },
                  {
                    'product_id': _otherProductId,
                    'storage_path': 'products/shoes.png',
                    'is_primary': true,
                  },
                ];
              },
        );

        final result = await repo.getCart();

        expect(variantSelect, supabaseCartVariantSelect);
        expect(variantSelect, isNot(contains('cost_price')));
        expect(variantSelect, isNot(contains('*')));
        expect(variantIds.toSet(), {_variantId, _otherVariantId});
        expect(productSelect, supabaseCartProductSelect);
        expect(productIds, [_otherProductId, _productId]..sort());
        expect(imageSelect, supabaseCartProductImageSelect);
        expect(imageProductIds, [_otherProductId, _productId]..sort());

        expect(result, isA<Success<Cart>>());
        final items = (result as Success<Cart>).data.items;
        expect(items, hasLength(2));

        expect(items[0].id, _itemId);
        expect(items[0].cartId, _cartId);
        expect(items[0].variantId, _variantId);
        expect(items[0].quantity, 2);
        expect(items[0].unitPriceSnapshot, 150000);
        expect(items[0].productId, _productId);
        expect(items[0].productName, 'Astrox 88');
        expect(items[0].variantLabel, '3U / G5 • Red • 3U • G5');
        expect(items[0].imagePath, 'products/astrox.png');

        expect(items[1].unitPriceSnapshot, 99000);
        expect(items[1].productName, 'Court Shoes');
        expect(items[1].variantLabel, '42 • 42');
        expect(items[1].imagePath, 'products/shoes.png');
      },
    );

    test('skips product and image seams when cart has no items', () async {
      var variantCalls = 0;
      var productCalls = 0;
      var imageCalls = 0;

      final repo = _repo(
        findActiveCart:
            ({
              required String table,
              required String userId,
              required String status,
            }) async => _cartRow(),
        fetchCartById:
            ({required String table, required String cartId}) async =>
                _cartRow(),
        listCartItems:
            ({
              required String table,
              required String cartId,
              required String orderColumn,
            }) async => const [],
        fetchVariantsByIds:
            ({
              required String table,
              required String selectColumns,
              required List<String> ids,
            }) async {
              variantCalls++;
              return const [];
            },
        fetchProductsByIds:
            ({
              required String table,
              required String selectColumns,
              required List<String> ids,
            }) async {
              productCalls++;
              return const [];
            },
        fetchProductImages:
            ({
              required String table,
              required String selectColumns,
              required List<String> productIds,
            }) async {
              imageCalls++;
              return const [];
            },
      );

      final result = await repo.getCart();

      expect(variantCalls, 0);
      expect(productCalls, 0);
      expect(imageCalls, 0);
      expect((result as Success<Cart>).data.items, isEmpty);
    });
  });

  group('addItem', () {
    test('increments existing matching variant then reloads cart', () async {
      late String findTable;
      late String findCartId;
      late String findVariantId;
      late String updateTable;
      late String updateItemId;
      late int updateQuantity;

      final repo = _repoWithLoadedCart(
        findCartItemByVariant:
            ({
              required String table,
              required String cartId,
              required String variantId,
            }) async {
              findTable = table;
              findCartId = cartId;
              findVariantId = variantId;
              return _cartItemRow(quantity: 2);
            },
        updateCartItemQuantity:
            ({
              required String table,
              required String itemId,
              required int quantity,
            }) async {
              updateTable = table;
              updateItemId = itemId;
              updateQuantity = quantity;
            },
        itemRows: [_cartItemRow(quantity: 5)],
        variantRows: [_variantRow()],
        productRows: [
          {'id': _productId, 'name': 'Astrox 88'},
        ],
        imageRows: [
          {
            'product_id': _productId,
            'storage_path': 'products/astrox.png',
            'is_primary': true,
          },
        ],
      );

      final result = await repo.addItem(
        productId: _productId,
        variantId: _variantId,
        quantity: 3,
      );

      expect(findTable, 'cart_items');
      expect(findCartId, _cartId);
      expect(findVariantId, _variantId);
      expect(updateTable, 'cart_items');
      expect(updateItemId, _itemId);
      expect(updateQuantity, 5);
      expect(result, isA<Success<Cart>>());
      expect((result as Success<Cart>).data.items.single.quantity, 5);
    });

    test(
      'inserts new row with cart id, variant id, and quantity only',
      () async {
        late String insertTable;
        late Map<String, Object?> insertValues;
        var updateCalls = 0;

        final repo = _repoWithLoadedCart(
          findCartItemByVariant:
              ({
                required String table,
                required String cartId,
                required String variantId,
              }) async => null,
          updateCartItemQuantity:
              ({
                required String table,
                required String itemId,
                required int quantity,
              }) async {
                updateCalls++;
              },
          insertCartItem:
              ({
                required String table,
                required Map<String, Object?> values,
              }) async {
                insertTable = table;
                insertValues = Map<String, Object?>.from(values);
              },
          itemRows: [_cartItemRow(quantity: 1)],
          variantRows: [_variantRow()],
          productRows: [
            {'id': _productId, 'name': 'Astrox 88'},
          ],
          imageRows: const [],
        );

        final result = await repo.addItem(
          productId: _productId,
          variantId: _variantId,
          quantity: 1,
        );

        expect(updateCalls, 0);
        expect(insertTable, 'cart_items');
        expect(insertValues.keys.toSet(), {
          'cart_id',
          'variant_id',
          'quantity',
        });
        expect(insertValues['cart_id'], _cartId);
        expect(insertValues['variant_id'], _variantId);
        expect(insertValues['quantity'], 1);
        expect(result, isA<Success<Cart>>());
      },
    );

    test('maps PostgrestException to DatabaseException with code', () async {
      final repo = _repo(
        findActiveCart:
            ({
              required String table,
              required String userId,
              required String status,
            }) async => _cartRow(),
        findCartItemByVariant:
            ({
              required String table,
              required String cartId,
              required String variantId,
            }) async {
              throw const PostgrestException(
                message: 'add failed',
                code: '23505',
              );
            },
      );

      final result = await repo.addItem(
        productId: _productId,
        variantId: _variantId,
        quantity: 1,
      );

      expect(result, isA<Failure<Cart>>());
      expect(
        ((result as Failure<Cart>).error as DatabaseException).code,
        '23505',
      );
    });
  });

  group('updateQuantity', () {
    test('positive quantity updates only the requested item', () async {
      late String updateTable;
      late String updateItemId;
      late int updateQuantity;
      var deleteCalls = 0;

      final repo = _repoWithLoadedCart(
        updateCartItemQuantity:
            ({
              required String table,
              required String itemId,
              required int quantity,
            }) async {
              updateTable = table;
              updateItemId = itemId;
              updateQuantity = quantity;
            },
        deleteCartItemById:
            ({required String table, required String itemId}) async {
              deleteCalls++;
            },
        itemRows: [_cartItemRow(quantity: 4)],
        variantRows: [_variantRow()],
        productRows: [
          {'id': _productId, 'name': 'Astrox 88'},
        ],
        imageRows: const [],
      );

      final result = await repo.updateQuantity(itemId: _itemId, quantity: 4);

      expect(deleteCalls, 0);
      expect(updateTable, 'cart_items');
      expect(updateItemId, _itemId);
      expect(updateQuantity, 4);
      expect(result, isA<Success<Cart>>());
    });

    test('zero quantity deletes the item', () async {
      late String deleteTable;
      late String deleteItemId;
      var updateCalls = 0;

      final repo = _repoWithLoadedCart(
        updateCartItemQuantity:
            ({
              required String table,
              required String itemId,
              required int quantity,
            }) async {
              updateCalls++;
            },
        deleteCartItemById:
            ({required String table, required String itemId}) async {
              deleteTable = table;
              deleteItemId = itemId;
            },
      );

      final result = await repo.updateQuantity(itemId: _itemId, quantity: 0);

      expect(updateCalls, 0);
      expect(deleteTable, 'cart_items');
      expect(deleteItemId, _itemId);
      expect(result, isA<Success<Cart>>());
      expect((result as Success<Cart>).data.items, isEmpty);
    });

    test('negative quantity deletes the item', () async {
      late String deleteItemId;

      final repo = _repoWithLoadedCart(
        deleteCartItemById:
            ({required String table, required String itemId}) async {
              deleteItemId = itemId;
            },
      );

      final result = await repo.updateQuantity(itemId: _itemId, quantity: -2);

      expect(deleteItemId, _itemId);
      expect(result, isA<Success<Cart>>());
    });

    test('maps PostgrestException to DatabaseException with code', () async {
      final repo = _repo(
        updateCartItemQuantity:
            ({
              required String table,
              required String itemId,
              required int quantity,
            }) async {
              throw const PostgrestException(
                message: 'update failed',
                code: 'PGRST116',
              );
            },
      );

      final result = await repo.updateQuantity(itemId: _itemId, quantity: 2);

      expect(result, isA<Failure<Cart>>());
      expect(
        ((result as Failure<Cart>).error as DatabaseException).code,
        'PGRST116',
      );
    });
  });

  group('removeItem', () {
    test('deletes by item id then returns reloaded cart', () async {
      late String deleteTable;
      late String deleteItemId;

      final repo = _repoWithLoadedCart(
        deleteCartItemById:
            ({required String table, required String itemId}) async {
              deleteTable = table;
              deleteItemId = itemId;
            },
      );

      final result = await repo.removeItem(_itemId);

      expect(deleteTable, 'cart_items');
      expect(deleteItemId, _itemId);
      expect(result, isA<Success<Cart>>());
      expect((result as Success<Cart>).data.id, _cartId);
    });

    test('maps PostgrestException to DatabaseException with code', () async {
      final repo = _repo(
        deleteCartItemById:
            ({required String table, required String itemId}) async {
              throw const PostgrestException(
                message: 'remove failed',
                code: '42P01',
              );
            },
      );

      final result = await repo.removeItem(_itemId);

      expect(result, isA<Failure<Cart>>());
      expect(
        ((result as Failure<Cart>).error as DatabaseException).code,
        '42P01',
      );
    });
  });

  group('clear', () {
    test(
      'deletes all items for the active cart and returns void success',
      () async {
        late String deleteTable;
        late String deleteCartId;

        final repo = _repo(
          findActiveCart:
              ({
                required String table,
                required String userId,
                required String status,
              }) async => _cartRow(),
          deleteCartItemsByCart:
              ({required String table, required String cartId}) async {
                deleteTable = table;
                deleteCartId = cartId;
              },
        );

        final result = await repo.clear();

        expect(deleteTable, 'cart_items');
        expect(deleteCartId, _cartId);
        expect(result, isA<Success<void>>());
      },
    );

    test('maps PostgrestException to DatabaseException with code', () async {
      final repo = _repo(
        findActiveCart:
            ({
              required String table,
              required String userId,
              required String status,
            }) async => _cartRow(),
        deleteCartItemsByCart:
            ({required String table, required String cartId}) async {
              throw const PostgrestException(
                message: 'clear failed',
                code: '42501',
              );
            },
      );

      final result = await repo.clear();

      expect(result, isA<Failure<void>>());
      expect(
        ((result as Failure<void>).error as DatabaseException).code,
        '42501',
      );
    });
  });
}

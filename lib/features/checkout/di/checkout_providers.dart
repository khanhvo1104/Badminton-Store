import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Checkout DI composition root.
/// Payment gateway adapters will be registered here in a later milestone.
final checkoutReadyProvider = Provider<bool>((ref) => false);

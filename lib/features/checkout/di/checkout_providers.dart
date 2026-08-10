import 'package:base_project/core/supabase/supabase_providers.dart';
import 'package:base_project/features/checkout/data/repositories/supabase_checkout_repository.dart';
import 'package:base_project/features/checkout/domain/repositories/checkout_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Checkout DI composition root.
final checkoutRepositoryProvider = Provider<CheckoutRepository>((ref) {
  return SupabaseCheckoutRepository.fromClient(
    ref.watch(supabaseClientProvider),
  );
});

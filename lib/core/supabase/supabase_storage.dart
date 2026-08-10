/// Contract for Supabase Storage (product images, avatars, invoices).
///
/// Implementations will wrap `supabase.storage` in a later milestone.
/// No upload/download methods are implemented in Shop Foundation.
abstract interface class SupabaseStorage {
  // Bucket helpers and signed URL generation will be declared
  // when media pipelines are connected.
}

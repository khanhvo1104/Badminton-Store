/// Future home for local persistence abstractions (e.g. cached catalog pages).
///
/// Remote truth remains Supabase. This module will host optional on-device
/// caches without coupling features to a specific database engine.
abstract final class DatabaseConstants {
  static const String schemaVersionKey = 'local_schema_version';
  static const int currentSchemaVersion = 1;
}

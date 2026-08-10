import 'package:base_project/core/errors/error_mapper.dart';
import 'package:base_project/core/logging/logger_provider.dart';
import 'package:base_project/core/network/network_info_provider.dart';
import 'package:base_project/core/supabase/supabase_providers.dart';
import 'package:base_project/features/profile/data/data_sources/profile_remote_data_source.dart';
import 'package:base_project/features/profile/data/data_sources/supabase_profile_remote_data_source.dart';
import 'package:base_project/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:base_project/features/profile/domain/repositories/profile_repository.dart';
import 'package:base_project/features/profile/domain/use_cases/update_profile_use_case.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final profileRemoteDataSourceProvider = Provider<ProfileRemoteDataSource>((
  ref,
) {
  return SupabaseProfileRemoteDataSource(ref.watch(supabaseClientProvider));
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final logger = ref.watch(appLoggerProvider);
  return ProfileRepositoryImpl(
    remoteDataSource: ref.watch(profileRemoteDataSourceProvider),
    networkInfo: ref.watch(networkInfoProvider),
    errorMapper: ErrorMapper(logger),
    logger: logger,
  );
});

final updateProfileUseCaseProvider = Provider<UpdateProfileUseCase>((ref) {
  return UpdateProfileUseCase(ref.watch(profileRepositoryProvider));
});

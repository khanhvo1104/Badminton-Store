import 'package:base_project/core/ui/glass/glass_background.dart';
import 'package:base_project/core/ui/glass/glass_error_view.dart';
import 'package:base_project/core/ui/glass/glass_loading_indicator.dart';
import 'package:base_project/shared/session/auth_session_provider.dart';
import 'package:base_project/shared/session/auth_session_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);

    return GlassBackground(
      enableAmbientMotion: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: session is AuthSessionError
            ? GlassErrorView(
                message: session.message,
                onRetry: () =>
                    ref.read(authSessionProvider.notifier).restoreSession(),
              )
            : const GlassLoadingIndicator(message: 'Starting...'),
      ),
    );
  }
}

import 'package:base_project/core/config/app_environment.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.enableNetworkLogs,
    required this.enableDebugTools,
  });

  factory AppConfig.fromEnvironment(AppEnvironment environment) {
    const definedBaseUrl = String.fromEnvironment('API_BASE_URL');
    final apiBaseUrl = definedBaseUrl.isNotEmpty
        ? definedBaseUrl
        : dotenv.get('API_BASE_URL', fallback: '');

    if (apiBaseUrl.isEmpty) {
      throw StateError(
        'API_BASE_URL is missing. Provide it via --dart-define or .env file.',
      );
    }

    const definedLogs = String.fromEnvironment('ENABLE_NETWORK_LOGS');
    const definedDebug = String.fromEnvironment('ENABLE_DEBUG_TOOLS');

    return AppConfig(
      environment: environment,
      apiBaseUrl: apiBaseUrl,
      enableNetworkLogs: _resolveFlag(
        definedLogs,
        dotenv.get('ENABLE_NETWORK_LOGS', fallback: 'false'),
      ),
      enableDebugTools: _resolveFlag(
        definedDebug,
        dotenv.get('ENABLE_DEBUG_TOOLS', fallback: 'false'),
      ),
    );
  }

  final AppEnvironment environment;
  final String apiBaseUrl;
  final bool enableNetworkLogs;
  final bool enableDebugTools;

  static bool _resolveFlag(String fromDefine, String fromEnv) {
    if (fromDefine.isNotEmpty) {
      return fromDefine == 'true';
    }
    return fromEnv == 'true';
  }
}

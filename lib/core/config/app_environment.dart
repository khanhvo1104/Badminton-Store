enum AppEnvironment {
  development,
  staging,
  production;

  String get displayName => switch (this) {
    AppEnvironment.development => 'Development',
    AppEnvironment.staging => 'Staging',
    AppEnvironment.production => 'Production',
  };

  String get envFileName => switch (this) {
    AppEnvironment.development => '.env.development',
    AppEnvironment.staging => '.env.staging',
    AppEnvironment.production => '.env.production',
  };
}

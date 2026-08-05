import 'package:base_project/app/configuration_error_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows accessible configuration guidance without secrets', (
    tester,
  ) async {
    // Sentinel strings that must never appear in the error UX.
    const sentinelUrl = 'https://sentinel-should-never-appear.example';
    const sentinelKey = 'sentinel-key-must-not-leak';

    await tester.pumpWidget(const ConfigurationErrorApp());

    expect(find.text(ConfigurationErrorApp.title), findsOneWidget);
    expect(find.text(ConfigurationErrorApp.guidance), findsOneWidget);
    expect(find.textContaining('SUPABASE_URL'), findsOneWidget);
    expect(find.textContaining('SUPABASE_PUBLISHABLE_KEY'), findsOneWidget);
    expect(find.textContaining('SUPABASE_ANON_KEY'), findsOneWidget);
    expect(find.textContaining('restart'), findsOneWidget);

    expect(find.textContaining(sentinelUrl), findsNothing);
    expect(find.textContaining(sentinelKey), findsNothing);

    expect(
      tester.getSemantics(find.text(ConfigurationErrorApp.title)),
      matchesSemantics(isHeader: true, label: ConfigurationErrorApp.title),
    );

    final guidanceSemantics = tester.getSemantics(
      find.text(ConfigurationErrorApp.guidance),
    );
    expect(guidanceSemantics.label, ConfigurationErrorApp.guidance);
  });
}

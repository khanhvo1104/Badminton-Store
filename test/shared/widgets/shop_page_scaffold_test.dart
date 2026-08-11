import 'package:base_project/app/theme/app_theme.dart';
import 'package:base_project/core/ui/glass/glass_background.dart';
import 'package:base_project/shared/widgets/shop_page_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'ShopPageScaffold paints light glass behind a transparent scaffold',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.dark,
          home: ShopPageScaffold(
            appBar: AppBar(title: const Text('Child')),
            body: const Text('Body copy'),
          ),
        ),
      );

      expect(find.byType(GlassBackground), findsOneWidget);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, Colors.transparent);

      final context = tester.element(find.text('Child'));
      final theme = Theme.of(context);
      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.onSurface.computeLuminance(), lessThan(0.5));
    },
  );
}

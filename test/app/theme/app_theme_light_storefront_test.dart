import 'package:base_project/app/theme/app_colors.dart';
import 'package:base_project/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTheme light storefront surfaces', () {
    test('light theme uses a non-black mint/off-white scaffold surface', () {
      final theme = AppTheme.light();

      expect(theme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, AppColors.surfaceTintLight);
      expect(theme.scaffoldBackgroundColor, isNot(Colors.transparent));
      expect(theme.scaffoldBackgroundColor, isNot(Colors.black));
      expect(
        theme.scaffoldBackgroundColor.computeLuminance(),
        greaterThan(0.5),
      );
      expect(theme.colorScheme.surface.computeLuminance(), greaterThan(0.5));
      expect(theme.colorScheme.onSurface.computeLuminance(), lessThan(0.5));
    });

    test(
      'dark factory keeps the deliberate light storefront under host dark appearance',
      () {
        final theme = AppTheme.dark();

        expect(theme.brightness, Brightness.light);
        expect(theme.scaffoldBackgroundColor, AppColors.surfaceTintLight);
        expect(
          theme.scaffoldBackgroundColor.computeLuminance(),
          greaterThan(0.5),
        );
        expect(theme.colorScheme.onSurface.computeLuminance(), lessThan(0.5));
        expect(
          theme.dialogTheme.backgroundColor?.computeLuminance(),
          greaterThan(0.5),
        );
      },
    );

    test('dialog and sheet themes are opaque light surfaces', () {
      final theme = AppTheme.light();

      expect(theme.dialogTheme.backgroundColor, isNot(Colors.transparent));
      expect(
        theme.dialogTheme.backgroundColor!.computeLuminance(),
        greaterThan(0.5),
      );
      expect(theme.bottomSheetTheme.backgroundColor, isNot(Colors.transparent));
      expect(
        theme.bottomSheetTheme.backgroundColor!.computeLuminance(),
        greaterThan(0.5),
      );
    });

    testWidgets(
      'MaterialApp ThemeMode.dark still paints a light non-black scaffold',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: ThemeMode.dark,
            home: const Scaffold(body: Text('Child screen')),
          ),
        );

        final context = tester.element(find.text('Child screen'));
        final theme = Theme.of(context);
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        final surface =
            scaffold.backgroundColor ?? theme.scaffoldBackgroundColor;

        expect(theme.brightness, Brightness.light);
        expect(surface, isNot(Colors.transparent));
        expect(surface, isNot(Colors.black));
        expect(surface.computeLuminance(), greaterThan(0.5));
        expect(theme.colorScheme.onSurface.computeLuminance(), lessThan(0.5));
      },
    );
  });
}

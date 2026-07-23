import 'package:base_project/app/theme/app_theme.dart';
import 'package:base_project/core/ui/glass/glass_button.dart';
import 'package:base_project/core/ui/glass/glass_dialog.dart';
import 'package:base_project/core/ui/glass/glass_quality.dart';
import 'package:base_project/core/ui/glass/glass_text_field.dart';
import 'package:base_project/core/ui/glass/liquid_glass_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {GlassQuality quality = GlassQuality.medium}) {
  return MaterialApp(
    theme: AppTheme.light(quality: quality),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('LiquidGlassContainer renders child', (tester) async {
    await tester.pumpWidget(
      _wrap(const LiquidGlassContainer(child: Text('glass-child'))),
    );
    expect(find.text('glass-child'), findsOneWidget);
  });

  testWidgets('disabled quality keeps child readable', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const LiquidGlassContainer(enableBlur: true, child: Text('readable')),
        quality: GlassQuality.disabled,
      ),
    );
    expect(find.text('readable'), findsOneWidget);
  });

  testWidgets('GlassButton loading disables interaction', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _wrap(GlassButton(label: 'Go', isLoading: true, onPressed: () => taps++)),
    );
    await tester.tap(find.byType(GlassButton), warnIfMissed: false);
    expect(taps, 0);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('GlassButton disabled does not fire', (tester) async {
    await tester.pumpWidget(
      _wrap(const GlassButton(label: 'Nope', onPressed: null)),
    );
    await tester.tap(find.text('Nope'), warnIfMissed: false);
    expect(find.text('Nope'), findsOneWidget);
  });

  testWidgets('GlassTextField shows validation error', (tester) async {
    await tester.pumpWidget(
      _wrap(const GlassTextField(label: 'Email', errorText: 'Required')),
    );
    expect(find.text('Required'), findsOneWidget);
  });

  testWidgets('GlassDialog can be dismissed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () => showGlassDialog<void>(
                  context: context,
                  title: 'Title',
                  description: 'Body',
                  cancelLabel: 'Cancel',
                ),
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Title'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Title'), findsNothing);
  });
}

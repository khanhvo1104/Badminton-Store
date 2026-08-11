import 'package:base_project/app/router/route_refresh_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('refresh notifies listeners so GoRouter can reevaluate', () {
    final notifier = RouteRefreshNotifier();
    var notifications = 0;
    notifier
      ..addListener(() => notifications++)
      ..refresh()
      ..refresh();

    expect(notifications, 2);
    notifier.dispose();
  });
}

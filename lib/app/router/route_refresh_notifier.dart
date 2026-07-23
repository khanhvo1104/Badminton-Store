import 'package:flutter/foundation.dart';

/// Notifies go_router when authentication session changes.
class RouteRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}

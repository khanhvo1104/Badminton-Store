import 'package:meta/meta.dart';

@immutable
class DashboardItem {
  const DashboardItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.iconName,
  });

  final String id;
  final String title;
  final String subtitle;
  final String iconName;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DashboardItem &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            title == other.title &&
            subtitle == other.subtitle &&
            iconName == other.iconName;
  }

  @override
  int get hashCode => Object.hash(id, title, subtitle, iconName);
}

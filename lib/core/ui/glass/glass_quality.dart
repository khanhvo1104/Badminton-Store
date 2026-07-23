enum GlassQuality {
  disabled,
  low,
  medium,
  high;

  String get storageValue => name;

  static GlassQuality fromStorage(String? value) {
    return GlassQuality.values.firstWhere(
      (q) => q.name == value,
      orElse: () => GlassQuality.medium,
    );
  }

  String get label => switch (this) {
    GlassQuality.disabled => 'Disabled',
    GlassQuality.low => 'Low',
    GlassQuality.medium => 'Medium',
    GlassQuality.high => 'High',
  };
}

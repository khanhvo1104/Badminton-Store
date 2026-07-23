abstract final class Validators {
  static final RegExp _emailPattern = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  static String? email(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Email is required';
    }
    if (!_emailPattern.hasMatch(trimmed)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? password(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return 'Password is required';
    }
    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  static String? displayName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) {
      return 'Display name is required';
    }
    if (name.length < 2) {
      return 'Display name must be at least 2 characters';
    }
    if (name.length > 50) {
      return 'Display name must be at most 50 characters';
    }
    return null;
  }
}

import 'package:base_project/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators.email', () {
    test('rejects empty email', () {
      expect(Validators.email(''), 'Email is required');
      expect(Validators.email(null), 'Email is required');
    });

    test('rejects invalid email', () {
      expect(Validators.email('not-an-email'), isNotNull);
      expect(Validators.email('a@b'), isNotNull);
    });

    test('accepts valid email', () {
      expect(Validators.email('demo@example.com'), isNull);
    });
  });

  group('Validators.password', () {
    test('rejects short password', () {
      expect(Validators.password('short'), isNotNull);
    });

    test('accepts password with 8+ characters', () {
      expect(Validators.password('Password123'), isNull);
    });
  });

  group('Validators.displayName', () {
    test('rejects empty or short names', () {
      expect(Validators.displayName(''), isNotNull);
      expect(Validators.displayName('A'), isNotNull);
    });

    test('accepts valid display name', () {
      expect(Validators.displayName('Demo User'), isNull);
    });
  });
}

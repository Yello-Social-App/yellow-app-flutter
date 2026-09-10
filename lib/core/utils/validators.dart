/// Simple stateless field validators returning a user-facing error string,
/// or `null` when the value is valid — the shape `TextFormField.validator`
/// expects.
abstract final class Validators {
  static final RegExp _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  /// Matches the backend's `RegisterRequest.username` constraint exactly
  /// (3-32 chars, alphanumeric + underscore/dot).
  static final RegExp _handleRe = RegExp(r'^[a-zA-Z0-9_.]{3,32}$');

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your email';
    if (!_emailRe.hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  /// Matches the backend's `RegisterRequest.password` constraint
  /// (min 12 / max 128 chars) so a doomed request never leaves the device.
  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Enter your password';
    if (v.length < 12) return 'Password must be at least 12 characters';
    if (v.length > 128) return 'Password must be at most 128 characters';
    return null;
  }

  static String? handle(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Choose a username';
    if (!_handleRe.hasMatch(v)) {
      return '3-32 characters: letters, numbers, underscore or dot';
    }
    return null;
  }

  static String? required(String? value, {String message = 'Required'}) {
    if ((value ?? '').trim().isEmpty) return message;
    return null;
  }
}

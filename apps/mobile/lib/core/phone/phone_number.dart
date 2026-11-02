abstract final class PhoneNumber {
  static String digits(String raw) => raw.replaceAll(RegExp(r'\D'), '');

  /// The client always shows a fixed +86 prefix. Users may paste a full
  /// number; this normalizes either form to E.164 for the API.
  static String normalize(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('+')) {
      return '+${digits(trimmed)}';
    }
    final value = digits(trimmed);
    if (value.length == 13 && value.startsWith('86')) {
      return '+$value';
    }
    if (value.length == 11 && value.startsWith('1')) {
      return '+86$value';
    }
    return '+$value';
  }

  static String local(String raw) {
    final normalized = normalize(raw);
    return normalized.startsWith('+86')
        ? normalized.substring(3)
        : normalized.replaceFirst('+', '');
  }

  static bool isValidChina(String raw) {
    return RegExp(r'^\+861[3-9]\d{9}$').hasMatch(normalize(raw));
  }
}

/// The payload embedded in the web sign-in QR code.
///
/// Example:
/// `familytree://web-login?v=1&id=<uuid>&secret=<opaque-token>`
class WebLoginQrPayload {
  const WebLoginQrPayload({required this.id, required this.secret});

  final String id;
  final String secret;
}

/// Parses only our own QR scheme. Arbitrary URLs must never be treated as a
/// sign-in request, otherwise a malicious QR could submit a foreign secret.
WebLoginQrPayload? parseWebLoginPayload(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  if (uri == null) return null;
  if (uri.scheme.toLowerCase() != 'familytree') return null;
  if (uri.host.toLowerCase() != 'web-login') return null;
  final id = (uri.queryParameters['id'] ?? '').trim();
  final secret = (uri.queryParameters['secret'] ?? '').trim();
  if (id.length < 8 || id.length > 80) return null;
  if (secret.length < 20 || secret.length > 256) return null;
  return WebLoginQrPayload(id: id, secret: secret);
}

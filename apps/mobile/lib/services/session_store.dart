import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StoredSession {
  const StoredSession({
    required this.serverUrl,
    required this.token,
    this.expiresAt,
  });

  final String serverUrl;
  final String token;
  final DateTime? expiresAt;
}

class SessionStore {
  SessionStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  static const _serverKey = 'familytree.server_url';
  static const _tokenKey = 'familytree.session_token';
  static const _expiryKey = 'familytree.session_expires_at';

  final FlutterSecureStorage _storage;

  Future<StoredSession?> read() async {
    try {
      final values = await _storage.readAll();
      final token = values[_tokenKey]?.trim() ?? '';
      final serverUrl = values[_serverKey]?.trim() ?? '';
      if (token.isEmpty || serverUrl.isEmpty) return null;
      return StoredSession(
        serverUrl: serverUrl,
        token: token,
        expiresAt: DateTime.tryParse(values[_expiryKey] ?? ''),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(StoredSession session) async {
    try {
      await _storage.write(key: _serverKey, value: session.serverUrl);
      await _storage.write(key: _tokenKey, value: session.token);
      if (session.expiresAt != null) {
        await _storage.write(
          key: _expiryKey,
          value: session.expiresAt!.toUtc().toIso8601String(),
        );
      }
    } catch (_) {
      // A failed secure-storage write should not break the login itself.
    }
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _serverKey);
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _expiryKey);
    } catch (_) {
      // Ignore storage cleanup failures.
    }
  }
}

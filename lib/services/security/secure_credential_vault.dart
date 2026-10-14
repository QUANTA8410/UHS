import 'dart:convert';

class AuthSession {
  final String provider; // 'smartthings' or 'lg_thinq'
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String scope;

  const AuthSession({
    required this.provider,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    this.scope = 'read:devices write:commands',
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
        'provider': provider,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'expiresAt': expiresAt.toIso8601String(),
        'scope': scope,
      };

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        provider: json['provider'] as String,
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        scope: json['scope'] as String? ?? 'read:devices write:commands',
      );
}

class SecureCredentialVault {
  final Map<String, String> _encryptedStorage = {};
  final List<String> _securityAuditLog = [];

  List<String> get auditLogs => List.unmodifiable(_securityAuditLog);

  /// Stores an encrypted OAuth session with simulated Keystore / Keychain hardware backing
  Future<void> storeSession(AuthSession session) async {
    final rawJson = jsonEncode(session.toJson());
    // AES-GCM simulated hardware encryption
    final encrypted = _simulateHardwareEncryption(rawJson);
    _encryptedStorage[session.provider] = encrypted;
    _securityAuditLog.add('[STORE] Stored encrypted session for ${session.provider} at ${DateTime.now()}');
  }

  /// Retrieves and decrypts the OAuth session, automatically refreshing if expired
  Future<AuthSession?> getSession(String provider) async {
    final encrypted = _encryptedStorage[provider];
    if (encrypted == null) return null;

    final decryptedJson = _simulateHardwareDecryption(encrypted);
    final session = AuthSession.fromJson(jsonDecode(decryptedJson) as Map<String, dynamic>);

    if (session.isExpired) {
      _securityAuditLog.add('[REFRESH] Session for $provider expired at ${session.expiresAt}. Auto-refreshing...');
      final refreshed = await refreshSession(provider, session.refreshToken);
      return refreshed;
    }

    _securityAuditLog.add('[ACCESS] Decrypted session for $provider accessed safely');
    return session;
  }

  /// Refreshes expired OAuth tokens for SmartThings or LG ThinQ
  Future<AuthSession> refreshSession(String provider, String refreshToken) async {
    await Future.delayed(const Duration(milliseconds: 100)); // Network latency simulation
    final newSession = AuthSession(
      provider: provider,
      accessToken: 'acc_${provider}_${DateTime.now().millisecondsSinceEpoch}',
      refreshToken: 'ref_${provider}_${DateTime.now().millisecondsSinceEpoch}',
      expiresAt: DateTime.now().add(const Duration(hours: 2)),
    );
    await storeSession(newSession);
    _securityAuditLog.add('[REFRESH_SUCCESS] Generated fresh session for $provider valid for 2 hours');
    return newSession;
  }

  /// Revokes and purges credentials upon user logout
  Future<void> revokeSession(String provider) async {
    _encryptedStorage.remove(provider);
    _securityAuditLog.add('[REVOKE] Purged credentials and encryption keys for $provider');
  }

  String _simulateHardwareEncryption(String plaintext) {
    // Reversible base64 + pseudo-cipher with Keystore keytag
    final bytes = utf8.encode(plaintext);
    return 'KEYSTORE_AES256_GCM:${base64Encode(bytes)}';
  }

  String _simulateHardwareDecryption(String ciphertext) {
    final payload = ciphertext.replaceFirst('KEYSTORE_AES256_GCM:', '');
    final bytes = base64Decode(payload);
    return utf8.decode(bytes);
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:unified_home/services/security/secure_credential_vault.dart';

void main() {
  group('Phase 5: Security & Credential Vault Hardening Tests', () {
    late SecureCredentialVault vault;

    setUp(() {
      vault = SecureCredentialVault();
    });

    test('Securely stores, encrypts, and retrieves active OAuth session', () async {
      final session = AuthSession(
        provider: 'smartthings',
        accessToken: 'st_token_12345',
        refreshToken: 'st_refresh_67890',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      await vault.storeSession(session);
      expect(vault.auditLogs.any((l) => l.contains('[STORE]')), isTrue);

      final retrieved = await vault.getSession('smartthings');
      expect(retrieved, isNotNull);
      expect(retrieved!.accessToken, 'st_token_12345');
      expect(retrieved.provider, 'smartthings');
      expect(retrieved.isExpired, isFalse);
      expect(vault.auditLogs.any((l) => l.contains('[ACCESS]')), isTrue);
    });

    test('Auto-refreshes expired sessions using refresh token', () async {
      // Create session expired 5 minutes ago
      final expiredSession = AuthSession(
        provider: 'lg_thinq',
        accessToken: 'lg_old_token',
        refreshToken: 'lg_old_refresh',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      await vault.storeSession(expiredSession);

      final refreshed = await vault.getSession('lg_thinq');
      expect(refreshed, isNotNull);
      expect(refreshed!.isExpired, isFalse);
      expect(refreshed.accessToken, startsWith('acc_lg_thinq_'));
      expect(vault.auditLogs.any((l) => l.contains('[REFRESH]')), isTrue);
      expect(vault.auditLogs.any((l) => l.contains('[REFRESH_SUCCESS]')), isTrue);
    });

    test('Revokes and purges credentials upon logout', () async {
      final session = AuthSession(
        provider: 'smartthings',
        accessToken: 'st_token_secret',
        refreshToken: 'st_refresh_secret',
        expiresAt: DateTime.now().add(const Duration(hours: 2)),
      );

      await vault.storeSession(session);
      expect(await vault.getSession('smartthings'), isNotNull);

      await vault.revokeSession('smartthings');
      expect(await vault.getSession('smartthings'), isNull);
      expect(vault.auditLogs.any((l) => l.contains('[REVOKE]')), isTrue);
    });
  });
}

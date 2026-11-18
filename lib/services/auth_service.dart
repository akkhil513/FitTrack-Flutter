import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'token_store.dart';

class AuthService {
  static const String _clientId = '5mqksvmvu33fqsk9e570f22jcf';
  static const String _cognitoUrl =
      'https://cognito-idp.us-east-1.amazonaws.com/';

  static String? userId;
  static String? userEmail;
  static String? userName;
  static String? idToken;

  static const _storage = FlutterSecureStorage();
  static const _refreshKey = 'fittrack_refresh_token';

  /// Secure storage first; browser localStorage when it cannot encrypt or throws.
  static Future<String?> _readRefresh() async {
    try {
      final v = await _storage.read(key: _refreshKey);
      if (v != null && v.isNotEmpty) return v;
    } catch (_) {}
    return FallbackTokenStore.read(_refreshKey);
  }

  static Future<void> _writeRefresh(String value) async {
    try {
      await _storage.write(key: _refreshKey, value: value);
      FallbackTokenStore.delete(_refreshKey);
    } catch (_) {
      FallbackTokenStore.write(_refreshKey, value);
    }
  }

  static Future<void> _clearRefresh() async {
    try {
      await _storage.delete(key: _refreshKey);
    } catch (_) {}
    FallbackTokenStore.delete(_refreshKey);
  }

  /// Wire the API client so an expired token is refreshed automatically.
  static void init() {
    ApiService.onUnauthorized = refreshSession;
  }

  static void _applyIdToken(String token) {
    idToken = token;
    final parts = token.split('.');
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    userId = payload['sub'];
    userEmail = payload['email'];
    userName = payload['name'];
    ApiService.setToken(token);
  }

  /// Uses the stored refresh token to get a fresh ID token. Returns false when
  /// there is no stored session or Cognito rejects it.
  static Future<bool> refreshSession() async {
    try {
      final refresh = await _readRefresh();
      if (refresh == null || refresh.isEmpty) return false;

      final res = await http.post(
        Uri.parse(_cognitoUrl),
        headers: {
          'Content-Type': 'application/x-amz-json-1.1',
          'X-Amz-Target': 'AWSCognitoIdentityProviderService.InitiateAuth',
        },
        body: jsonEncode({
          'AuthFlow': 'REFRESH_TOKEN_AUTH',
          'ClientId': _clientId,
          'AuthParameters': {'REFRESH_TOKEN': refresh},
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _applyIdToken(data['AuthenticationResult']['IdToken']);
        return true;
      }
      // Refresh token revoked or expired: forget it.
      if (res.statusCode == 400) {
        await _clearRefresh();
      }
    } catch (_) {
      // Offline or storage unavailable: keep the stored token, report no session.
    }
    return false;
  }

  static Future<void> signIn({
    required String emailOrUsername,
    required String password,
  }) async {
    String email = emailOrUsername;

    // If not an email - look up by username
    if (!emailOrUsername.contains('@')) {
      try {
        final result = await ApiService.getUserByUsername(emailOrUsername);
        email = result['email'] ?? emailOrUsername;
      } catch (_) {
        // Try as-is if lookup fails
      }
    }

    final res = await http.post(
      Uri.parse(_cognitoUrl),
      headers: {
        'Content-Type': 'application/x-amz-json-1.1',
        'X-Amz-Target': 'AWSCognitoIdentityProviderService.InitiateAuth',
      },
      body: jsonEncode({
        'AuthFlow': 'USER_PASSWORD_AUTH',
        'ClientId': _clientId,
        'AuthParameters': {'USERNAME': email, 'PASSWORD': password},
      }),
    );

    final data = jsonDecode(res.body);

    if (res.statusCode == 200) {
      final result = data['AuthenticationResult'];
      _applyIdToken(result['IdToken']);
      final refresh = result['RefreshToken'];
      if (refresh != null) {
        await _writeRefresh(refresh);
      }
    } else {
      throw Exception(data['message'] ?? 'Login failed');
    }
  }

  static Future<void> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    final res = await http.post(
      Uri.parse(_cognitoUrl),
      headers: {
        'Content-Type': 'application/x-amz-json-1.1',
        'X-Amz-Target': 'AWSCognitoIdentityProviderService.SignUp',
      },
      body: jsonEncode({
        'ClientId': _clientId,
        'Username': email,
        'Password': password,
        'UserAttributes': [
          {'Name': 'email', 'Value': email},
          {'Name': 'name', 'Value': name},
        ],
      }),
    );

    final data = jsonDecode(res.body);
    if (res.statusCode != 200) {
      throw Exception(data['message'] ?? 'Sign up failed');
    }
  }

  static Future<void> confirmSignUp({
    required String email,
    required String code,
  }) async {
    final res = await http.post(
      Uri.parse(_cognitoUrl),
      headers: {
        'Content-Type': 'application/x-amz-json-1.1',
        'X-Amz-Target': 'AWSCognitoIdentityProviderService.ConfirmSignUp',
      },
      body: jsonEncode({
        'ClientId': _clientId,
        'Username': email,
        'ConfirmationCode': code,
      }),
    );

    final data = jsonDecode(res.body);
    if (res.statusCode != 200) {
      throw Exception(data['message'] ?? 'Confirmation failed');
    }
  }

  static void signOut() {
    userId = null;
    userEmail = null;
    userName = null;
    idToken = null;
    ApiService.clearToken();
    _clearRefresh();
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class AuthService {
  static const String _clientId = '5mqksvmvu33fqsk9e570f22jcf';
  static const String _cognitoUrl =
      'https://cognito-idp.us-east-1.amazonaws.com/';

  static String? userId;
  static String? userEmail;
  static String? userName;
  static String? idToken;

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
      idToken = data['AuthenticationResult']['IdToken'];
      final parts = idToken!.split('.');
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      userId = payload['sub'];
      userEmail = payload['email'];
      userName = payload['name'];
      ApiService.setToken(idToken!);
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
    ApiService.setToken('');
  }
}

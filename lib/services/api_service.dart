import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl =
      'https://cboo0mfp27.execute-api.us-east-1.amazonaws.com';

  static String? _token;

  /// Called once when a request comes back 401. Should refresh the token and
  /// return true if the request is worth retrying. Set by AuthService.
  static Future<bool> Function()? onUnauthorized;

  static void setToken(String token) {
    _token = token;
  }

  static void clearToken() {
    _token = null;
  }

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null && _token!.isNotEmpty) 'Authorization': 'Bearer $_token',
  };

  /// Runs a request, refreshing the session and retrying once on 401.
  static Future<http.Response> _send(
    Future<http.Response> Function() call,
  ) async {
    var res = await call();
    if (res.statusCode == 401 && onUnauthorized != null) {
      final refreshed = await onUnauthorized!();
      if (refreshed) res = await call();
    }
    return res;
  }

  static bool _ok(http.Response res) =>
      res.statusCode >= 200 && res.statusCode < 300;

  static Map<String, dynamic> _map(http.Response res) {
    if (res.body.trim().isEmpty) return {};
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ─── USER ───────────────────────────────────

  static Future<Map<String, dynamic>> getUser(String userId) async {
    final res = await _send(
      () => http.get(Uri.parse('$baseUrl/users/$userId'), headers: _headers),
    );
    return _map(res);
  }

  // Public route: used before sign-in to turn a username into an email.
  static Future<Map<String, dynamic>> getUserByUsername(String username) async {
    final res = await http.get(
      Uri.parse('$baseUrl/users/check/$username'),
      headers: _headers,
    );
    if (res.statusCode == 200) return _map(res);
    return {};
  }

  static Future<Map<String, dynamic>> createUser({
    required String firstName,
    required String lastName,
    required String email,
    required String username,
    required String userId,
  }) async {
    final res = await _send(
      () => http.post(
        Uri.parse('$baseUrl/users/create'),
        headers: _headers,
        body: jsonEncode({
          'userId': userId,
          'firstName': firstName,
          'lastName': lastName,
          'email': email,
          'username': username,
        }),
      ),
    );
    return _map(res);
  }

  static Future<void> updateUser({
    required String userId,
    required int challengeDuration,
    String? startDate,
    String firstName = '',
    String lastName = '',
  }) async {
    final body = jsonEncode({
      'userId': userId,
      'challengeDuration': challengeDuration.toString(),
      'startDate': startDate ?? DateTime.now().toIso8601String().split('T')[0],
      'firstName': firstName,
      'lastName': lastName,
    });

    final res = await _send(
      () => http.put(
        Uri.parse('$baseUrl/users/update/$userId'),
        headers: _headers,
        body: body,
      ),
    );

    if (!_ok(res)) {
      throw Exception('Failed to update user: ${res.statusCode}');
    }
  }

  static Future<void> saveMeasurements(
    String userId, {
    required String measurements,
    required String measurementHistory,
  }) async {
    final res = await _send(
      () => http.put(
        Uri.parse('$baseUrl/measurements/$userId'),
        headers: _headers,
        body: jsonEncode({
          'measurements': measurements,
          'measurementHistory': measurementHistory,
        }),
      ),
    );
    if (!_ok(res)) {
      throw Exception('Failed to save measurements: ${res.statusCode}');
    }
  }

  // ─── PLAN ───────────────────────────────────

  static Future<Map<String, dynamic>> getPlan(String userId) async {
    final res = await _send(
      () => http.get(Uri.parse('$baseUrl/plans/$userId'), headers: _headers),
    );
    return _map(res);
  }

  static Future<Map<String, dynamic>> generatePlan(
    Map<String, dynamic> payload,
  ) async {
    final res = await _send(
      () => http.post(
        Uri.parse('$baseUrl/plans/generate'),
        headers: _headers,
        body: jsonEncode(payload),
      ),
    );
    return _map(res);
  }

  static Future<void> generateWeeklyPlan({
    required String userId,
    required int weekNumber,
    required String previousLogs,
    required String userProfile,
  }) async {
    await _send(
      () => http.post(
        Uri.parse('$baseUrl/plans/generate-weekly'),
        headers: _headers,
        body: jsonEncode({
          'userId': userId,
          'weekNumber': weekNumber,
          'previousLogs': previousLogs,
          'userProfile': userProfile,
        }),
      ),
    );
  }

  // ─── LOGS ───────────────────────────────────

  static Future<List<dynamic>> getLogs(String userId) async {
    final res = await _send(
      () => http.get(Uri.parse('$baseUrl/logs/$userId'), headers: _headers),
    );
    if (!_ok(res) || res.body.trim().isEmpty) return [];
    return jsonDecode(res.body) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> getLogByDate(
    String userId,
    String date,
  ) async {
    final res = await _send(
      () => http.get(
        Uri.parse('$baseUrl/logs/$userId/$date'),
        headers: _headers,
      ),
    );
    if (res.statusCode == 200) return _map(res);
    return {};
  }

  static Future<void> saveLog(Map<String, dynamic> payload) async {
    final res = await _send(
      () => http.post(
        Uri.parse('$baseUrl/logs/createLog'),
        headers: _headers,
        body: jsonEncode(payload),
      ),
    );
    if (!_ok(res)) {
      throw Exception('Failed to save log: ${res.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> updateLog(
    String userId,
    String date,
    Map<String, dynamic> payload,
  ) async {
    final res = await _send(
      () => http.put(
        Uri.parse('$baseUrl/logs/update/$userId/$date'),
        headers: _headers,
        body: jsonEncode(payload),
      ),
    );
    return _map(res);
  }

  // ─── NUTRITION ──────────────────────────────

  static Future<Map<String, dynamic>> calculateMealMacros(
    String description,
  ) async {
    final res = await _send(
      () => http.post(
        Uri.parse('$baseUrl/nutrition/calculate'),
        headers: _headers,
        body: jsonEncode({'description': description}),
      ),
    );
    if (!_ok(res)) {
      throw Exception('Could not calculate macros (${res.statusCode})');
    }
    return _map(res);
  }

  // ─── MEAL TEMPLATES ─────────────────────────

  static Future<Map<String, dynamic>> getMealTemplates(String userId) async {
    final res = await _send(
      () => http.get(
        Uri.parse('$baseUrl/meal-templates/$userId'),
        headers: _headers,
      ),
    );
    return _map(res);
  }

  static Future<Map<String, dynamic>> saveMealTemplates(
    String userId,
    List<dynamic> templates,
  ) async {
    final res = await _send(
      () => http.put(
        Uri.parse('$baseUrl/meal-templates/$userId'),
        headers: _headers,
        body: jsonEncode({'mealTemplates': jsonEncode(templates)}),
      ),
    );
    if (!_ok(res)) {
      throw Exception('Failed to save meal templates: ${res.statusCode}');
    }
    return _map(res);
  }
}

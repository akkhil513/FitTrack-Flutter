import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl =
      'https://cboo0mfp27.execute-api.us-east-1.amazonaws.com';

  static String? _token;

  // Set token after login
  static void setToken(String token) {
    _token = token;
  }

  // Headers with auth token
  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  // ─── USER ───────────────────────────────────

  static Future<Map<String, dynamic>> getUser(String userId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/users/$userId'),
      headers: _headers,
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getUserByUsername(String username) async {
    final res = await http.get(
      Uri.parse('$baseUrl/users/check/$username'),
      headers: _headers,
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return {};
  }

  static Future<Map<String, dynamic>> createUser({
    required String firstName,
    required String lastName,
    required String email,
    required String username,
    required String userId,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/users/create'),
      headers: _headers,
      body: jsonEncode({
        'userId': userId,
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'username': username,
      }),
    );
    return jsonDecode(res.body);
  }

  static Future<void> updateUser({
    required String userId,
    required int challengeDuration,
    String? startDate,
  }) async {
    final body = jsonEncode({
      'userId': userId,
      'challengeDuration': challengeDuration.toString(),
      'startDate': startDate ?? DateTime.now().toIso8601String().split('T')[0],
      'firstName': '',
      'lastName': '',
    });

    var res = await http.put(
      Uri.parse('$baseUrl/users/$userId'),
      headers: _headers,
      body: body,
    );

    if (res.statusCode >= 200 && res.statusCode < 300) return;

    // Fallback route for older backend deployments.
    res = await http.put(
      Uri.parse('$baseUrl/users/update/$userId'),
      headers: _headers,
      body: body,
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Failed to update user: ${res.statusCode}');
    }
  }

  // ─── PLAN ───────────────────────────────────

  static Future<Map<String, dynamic>> getPlan(String userId) async {
    print('=== GET PLAN URL: $baseUrl/plans/$userId');
    print('=== TOKEN: $_token');

    final res = await http.get(
      Uri.parse('$baseUrl/plans/$userId'),
      headers: _headers,
    );

    print('=== PLAN STATUS CODE: ${res.statusCode}');
    print('=== PLAN RESPONSE: ${res.body}');

    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> generatePlan(
    Map<String, dynamic> payload,
  ) async {
    final res = await http.post(
      Uri.parse('$baseUrl/plans/generate'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    return jsonDecode(res.body);
  }

  static Future<void> generateWeeklyPlan({
    required String userId,
    required int weekNumber,
    required String previousLogs,
    required String userProfile,
  }) async {
    await http.post(
      Uri.parse('$baseUrl/plans/generate-weekly'),
      headers: _headers,
      body: jsonEncode({
        'userId': userId,
        'weekNumber': weekNumber,
        'previousLogs': previousLogs,
        'userProfile': userProfile,
      }),
    );
  }

  // ─── LOGS ───────────────────────────────────

  static Future<List<dynamic>> getLogs(String userId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/logs/$userId'),
      headers: _headers,
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getLogByDate(
    String userId,
    String date,
  ) async {
    final res = await http.get(
      Uri.parse('$baseUrl/logs/$userId/$date'),
      headers: _headers,
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return {};
  }

  static Future<void> saveLog(Map<String, dynamic> payload) async {
    await http.post(
      Uri.parse('$baseUrl/logs/createLog'),
      headers: _headers,
      body: jsonEncode(payload),
    );
  }

  static Future<Map<String, dynamic>> updateLog(
    String userId,
    String date,
    Map<String, dynamic> payload,
  ) async {
    final res = await http.put(
      Uri.parse('$baseUrl/logs/update/$userId/$date'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    return jsonDecode(res.body);
  }

  // ─── NUTRITION ──────────────────────────────

  static Future<Map<String, dynamic>> calculateMealMacros(
    String description,
  ) async {
    final res = await http.post(
      Uri.parse('$baseUrl/nutrition/calculate'),
      headers: _headers,
      body: jsonEncode({'description': description}),
    );
    return jsonDecode(res.body);
  }

  // ─── MEAL TEMPLATES ─────────────────────────

  static Future<Map<String, dynamic>> getMealTemplates(String userId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/meal-templates/$userId'),
      headers: _headers,
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> saveMealTemplates(
    String userId,
    List<dynamic> templates,
  ) async {
    final res = await http.put(
      Uri.parse('$baseUrl/meal-templates/$userId'),
      headers: _headers,
      body: jsonEncode({'mealTemplates': jsonEncode(templates)}),
    );
    return jsonDecode(res.body);
  }
}

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

  // ─── PLAN ───────────────────────────────────

  static Future<Map<String, dynamic>> getPlan(String userId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/plans/$userId'),
      headers: _headers,
    );
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
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> saveLog(
    Map<String, dynamic> payload,
  ) async {
    final res = await http.post(
      Uri.parse('$baseUrl/logs/createLog'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    return jsonDecode(res.body);
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

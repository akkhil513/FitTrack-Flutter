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

  // ─── SUPPLEMENT REMINDERS ───────────────────

  static Future<void> saveGoals(String userId, String goalsJson) async {
    final res = await _send(
      () => http.put(
        Uri.parse('$baseUrl/goals/$userId'),
        headers: _headers,
        body: jsonEncode({'goals': goalsJson}),
      ),
    );
    if (!_ok(res)) {
      throw Exception('Could not save goals (${res.statusCode})');
    }
  }

  static Future<void> saveSupplementReminders(
    String userId,
    List<Map<String, dynamic>> reminders,
  ) async {
    final res = await _send(
      () => http.put(
        Uri.parse('$baseUrl/supplements/$userId'),
        headers: _headers,
        body: jsonEncode({'supplementReminders': jsonEncode(reminders)}),
      ),
    );
    if (!_ok(res)) {
      throw Exception('Could not save reminders (${res.statusCode})');
    }
  }

  /// Asks the AI for the best time of day for the named supplement(s).
  /// Returns {"time": "HH:mm", "reason": "..."}.
  static Future<Map<String, dynamic>> suggestSupplementTime(
    String userId,
    String name,
  ) async {
    final res = await _send(
      () => http.post(
        Uri.parse('$baseUrl/supplements/$userId/suggest-time'),
        headers: _headers,
        body: jsonEncode({'name': name}),
      ),
    );
    if (!_ok(res)) {
      throw Exception('Suggestion failed (${res.statusCode})');
    }
    return _map(res);
  }

  // ─── WORKOUT CHANGES ────────────────────────

  /// Marks a training day as skipped (or clears the mark with skipped: false).
  static Future<void> skipDay(
    String userId,
    String date, {
    required int dayNumber,
    bool skipped = true,
  }) async {
    final res = await _send(
      () => http.post(
        Uri.parse('$baseUrl/logs/$userId/$date/skip'),
        headers: _headers,
        body: jsonEncode({'skipped': skipped, 'dayNumber': dayNumber}),
      ),
    );
    if (!_ok(res)) {
      throw Exception('Could not skip the day (${res.statusCode})');
    }
  }

  /// Asks the server to replace one exercise. Returns the updated training JSON string.
  static Future<String> swapExercise(
    String userId, {
    required String day,
    required String exercise,
    String reason = '',
  }) async {
    final res = await _send(
      () => http.post(
        Uri.parse('$baseUrl/plans/$userId/swap'),
        headers: _headers,
        body: jsonEncode({'day': day, 'exercise': exercise, 'reason': reason}),
      ),
    );
    final body = _map(res);
    if (!_ok(res)) {
      throw Exception(body['message']?.toString() ?? 'Swap failed (${res.statusCode})');
    }
    return body['training'].toString();
  }

  // ─── PROGRESS PHOTOS ────────────────────────

  /// Asks the API for a short-lived signed upload URL for one photo.
  static Future<({String key, String uploadUrl})> requestPhotoUpload(
    String userId, {
    required String date,
    required String angle,
    required int size,
  }) async {
    final res = await _send(
      () => http.post(
        Uri.parse('$baseUrl/photos/$userId/upload-url'),
        headers: _headers,
        body: jsonEncode({
          'date': date,
          'angle': angle,
          'contentType': 'image/jpeg',
          'size': size,
        }),
      ),
    );
    final body = _map(res);
    if (!_ok(res)) {
      throw Exception(body['message']?.toString() ?? 'Upload failed (${res.statusCode})');
    }
    return (key: body['key'].toString(), uploadUrl: body['uploadUrl'].toString());
  }

  /// Sends the bytes straight to S3. No app headers: the signed URL carries its own credentials,
  /// and an extra Authorization header would break the signature.
  static Future<void> putPhotoBytes(String uploadUrl, List<int> bytes) async {
    final res = await http.put(
      Uri.parse(uploadUrl),
      headers: const {'Content-Type': 'image/jpeg'},
      body: bytes,
    );
    if (!_ok(res)) {
      throw Exception('Upload failed (${res.statusCode})');
    }
  }

  static Future<List<dynamic>> listPhotos(String userId) async {
    final res = await _send(
      () => http.get(Uri.parse('$baseUrl/photos/$userId'), headers: _headers),
    );
    if (!_ok(res)) {
      throw Exception('Could not load photos (${res.statusCode})');
    }
    final photos = _map(res)['photos'];
    return photos is List ? photos : <dynamic>[];
  }

  static Future<void> deletePhoto(String userId, String key) async {
    final res = await _send(
      () => http.delete(
        Uri.parse('$baseUrl/photos/$userId').replace(queryParameters: {'key': key}),
        headers: _headers,
      ),
    );
    if (!_ok(res)) {
      throw Exception('Could not delete the photo (${res.statusCode})');
    }
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

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  // For iOS simulator use localhost
  // For Android emulator use 10.0.2.2
  // For real device use your Mac IP address (run: ifconfig | grep inet)
  // static const String baseUrl = 'http://localhost:3000';
  // static const String baseUrl = "http://10.0.2.2:3000";

  static const String baseUrl = 'http://192.168.1.112:3000';

  // static String get baseUrl {
  //   if (Platform.isAndroid) {
  //     return "http://10.0.2.2:3000";
  //   } else {
  //     return "http://localhost:3000";
  //   }
  // }

  static String? _token;
  static void setToken(String token) => _token = token;
  static void clearToken() => _token = null;

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  static Future<Map<String, dynamic>> requestAttendanceCorrection(
    int attendanceId,
    String reason,
  ) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/attendance/$attendanceId/request-correction'),
      headers: _headers,
      body: jsonEncode({'reason': reason}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> updateAttendance(
    int id,
    String status,
  ) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/api/attendance/$id'),
      headers: _headers,
      body: jsonEncode({'status': status}),
    );
    return jsonDecode(res.body);
  }

  static String? get currentToken => _token;

  // ── Auth ───────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> updatePassword(
    int userId,
    String password,
  ) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/api/users/$userId'),
      headers: _headers,
      body: jsonEncode({'password': password}),
    );
    return jsonDecode(res.body);
  }

  // ── Organisations ──────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getOrganisations() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/organisations'),
      headers: _headers,
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> createOrganisation(
    Map<String, dynamic> data,
  ) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/organisations'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> deleteOrganisation(int id) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/api/organisations/$id'),
      headers: _headers,
    );
    return jsonDecode(res.body);
  }

  // ── Users ──────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getUsers({String? role}) async {
    final url = role != null
        ? '$baseUrl/api/users?role=$role'
        : '$baseUrl/api/users';
    final res = await http.get(Uri.parse(url), headers: _headers);
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> deleteUser(int id) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/api/users/$id'),
      headers: _headers,
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> toggleUser(int id) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/api/users/$id/toggle'),
      headers: _headers,
    );
    return jsonDecode(res.body);
  }

  // ── Invitations ────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> sendInvitation(
    Map<String, dynamic> data,
  ) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/invitations'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getInvitations() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/invitations'),
      headers: _headers,
    );
    return jsonDecode(res.body);
  }

  // ── Classes ────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getClasses() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/classes'),
      headers: _headers,
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getClassDetail(int id) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/classes/$id'),
      headers: _headers,
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> createClass(
    Map<String, dynamic> data,
  ) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/classes'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> deleteClass(int id) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/api/classes/$id'),
      headers: _headers,
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> enrolStudent(
    int classId,
    int studentId,
  ) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/classes/$classId/enrol'),
      headers: _headers,
      body: jsonEncode({'studentId': studentId}),
    );
    return jsonDecode(res.body);
  }

  // ── Sessions ───────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getSessions() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/sessions'),
      headers: _headers,
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getSessionDetail(int id) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/sessions/$id'),
      headers: _headers,
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> createSession(
    Map<String, dynamic> data,
  ) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/sessions'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> activateSession(int id) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/api/sessions/$id/activate'),
      headers: _headers,
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> closeSession(int id) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/api/sessions/$id/close'),
      headers: _headers,
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> deleteSession(int id) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/api/sessions/$id'),
      headers: _headers,
    );
    return jsonDecode(res.body);
  }

  // ── Attendance ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> markAttendance(
    File imageFile,
    int userId,
    int sessionId,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/attendance/mark'),
    );
    request.headers['Authorization'] = 'Bearer $_token';
    request.files.add(
      await http.MultipartFile.fromPath('image', imageFile.path),
    );
    request.fields['userId'] = userId.toString();
    request.fields['sessionId'] = sessionId.toString();
    final response = await request.send();
    final body = await response.stream.bytesToString();
    return jsonDecode(body);
  }

  static Future<Map<String, dynamic>> getStudentHistory(int userId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/attendance/$userId'),
      headers: _headers,
    );
    return jsonDecode(res.body);
  }

  // ── Face ───────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> enrollFace(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final b64 = base64Encode(bytes);
    final res = await http.post(
      Uri.parse('$baseUrl/api/face/enroll'),
      headers: _headers,
      body: jsonEncode({
        'images': [b64],
      }),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getFaceStatus() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/face/status'),
      headers: _headers,
    );
    return jsonDecode(res.body);
  }

  // ── Dashboard ──────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getAdminDashboard() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/dashboard/admin'),
      headers: _headers,
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getTeacherDashboard(int classId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/dashboard/teacher/$classId'),
      headers: _headers,
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getStudentDashboard(int userId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/dashboard/student/$userId'),
      headers: _headers,
    );
    return jsonDecode(res.body);
  }

  // ── Messages ───────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getMessages() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/messages'),
      headers: _headers,
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getContacts() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/messages/contacts'),
      headers: _headers,
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> sendMessage(
    Map<String, dynamic> data,
  ) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/messages'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> replyMessage(int id, String body) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/messages/$id/reply'),
      headers: _headers,
      body: jsonEncode({'body': body}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getThread(int id) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/messages/thread/$id'),
      headers: _headers,
    );
    return jsonDecode(res.body);
  }

  // ── Notifications ──────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getNotifications() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/notifications'),
      headers: _headers,
    );
    return jsonDecode(res.body);
  }

  static Future<void> markNotificationRead(int id) async {
    await http.patch(
      Uri.parse('$baseUrl/api/notifications/$id/read'),
      headers: _headers,
    );
  }

  static Future<void> markAllNotificationsRead() async {
    await http.patch(
      Uri.parse('$baseUrl/api/notifications/read-all'),
      headers: _headers,
    );
  }
}

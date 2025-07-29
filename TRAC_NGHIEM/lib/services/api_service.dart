import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/user_prefs.dart';
import 'dart:io';

class ApiService {
  static const String baseUrl = 'http://172.16.7.64:5162';

  static Future<Map<String, String>> _getAuthHeaders() async {
    final token = await UserPrefs.getToken();
    if (token == null) {
      throw Exception('Token not found. User may not be logged in.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // --- Auth Functions ---
  static Future<http.Response> login(String email, String password) {
    return http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
  }
  /// Đổi mật khẩu của người dùng
  static Future<http.Response> changePassword(String currentPassword, String newPassword) async {
    final headers = await _getAuthHeaders();
    return http.put(
      Uri.parse('$baseUrl/api/users/password'),
      headers: headers,
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    );
  }
  /// Lấy danh sách thông báo (bài thi sắp hết hạn)
  static Future<List<Map<String, dynamic>>> getNotifications() async {
    final headers = await _getAuthHeaders();
    final url = Uri.parse('$baseUrl/api/student/notifications');
    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load notifications');
    }
  }
  /// Xóa tài khoản người dùng
  static Future<http.Response> deleteAccount(String password) async {
    final headers = await _getAuthHeaders();
    return http.delete( // Sử dụng phương thức DELETE
      Uri.parse('$baseUrl/api/users'),
      headers: headers,
      body: jsonEncode({
        'password': password,
        // Đã xóa trường reason
      }),
    );
  }
  static Future<http.Response> uploadAvatar(File imageFile) async {
    final token = await UserPrefs.getToken();
    final url = Uri.parse('$baseUrl/api/users/avatar');

    var request = http.MultipartRequest('POST', url);

    // Thêm token vào header
    request.headers['Authorization'] = 'Bearer $token';

    // Thêm file ảnh vào request
    request.files.add(
      await http.MultipartFile.fromPath(
        'file', // Tên field này phải khớp với tham số 'IFormFile file' trên server
        imageFile.path,
      ),
    );

    var streamedResponse = await request.send();
    return await http.Response.fromStream(streamedResponse);
  }
  /// Đặt lại mật khẩu (chức năng quên mật khẩu)
  static Future<http.Response> resetPassword(String email, String newPassword) async {
    // Hàm này không cần token xác thực
    return http.post(
      Uri.parse('$baseUrl/api/auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'newPassword': newPassword,
      }),
    );
  }
  /// Lấy bảng điểm của một bài thi (chức năng của giáo viên)
  static Future<List<Map<String, dynamic>>> getExamResultsForTeacher(int examId) async {
    final headers = await _getAuthHeaders();
    final url = Uri.parse('$baseUrl/api/teacher/exams/$examId/results');
    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load exam results');
    }
  }

  static Future<http.Response> register(Map<String, dynamic> userData) {
    return http.post(
      Uri.parse('$baseUrl/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(userData),
    );
  }

  // --- Student Functions ---
  static Future<List<Map<String, dynamic>>> getExamsByStatus(String status) async {
    final headers = await _getAuthHeaders();
    final url = Uri.parse('$baseUrl/api/student/exams?status=$status');
    final response = await http.get(url, headers: headers);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load exams with status: $status');
    }
  }

  static Future<http.Response> addExamToUser({required int examId, String? password}) async {
    final headers = await _getAuthHeaders();
    final url = Uri.parse('$baseUrl/api/student/exams');
    return http.post(
        url,
        headers: headers,
        body: jsonEncode({'examId': examId, 'password': password})
    );
  }

  static Future<List<Map<String, dynamic>>> getAttemptHistory(int examId) async {
    final headers = await _getAuthHeaders();
    final url = Uri.parse('$baseUrl/api/student/exams/$examId/history');
    final response = await http.get(url, headers: headers);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load attempt history');
    }
  }

  static Future<List<Map<String, dynamic>>> getQuestionsForQuiz(int examId) async {
    final headers = await _getAuthHeaders();
    final url = Uri.parse('$baseUrl/api/student/exams/$examId/questions');
    final response = await http.get(url, headers: headers);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load questions for quiz');
    }
  }
  /// Cập nhật email của user
  static Future<http.Response> updateUserEmail(String newEmail, String password) async {
    final headers = await _getAuthHeaders();
    return http.put(
      Uri.parse('$baseUrl/api/users/email'),
      headers: headers,
      body: jsonEncode({
        'newEmail': newEmail,
        'password': password,
      }),
    );
  }
  static Future<http.Response> submitQuiz(int examId, List<Map<String, int>> selectedAnswers) async {
    final headers = await _getAuthHeaders();
    final url = Uri.parse('$baseUrl/api/student/exams/$examId/submit');
    return http.post(
        url,
        headers: headers,
        body: jsonEncode({'selectedAnswers': selectedAnswers})
    );
  }

  static Future<List<dynamic>> getReviewData(int resultId) async {
    final headers = await _getAuthHeaders();
    final url = Uri.parse('$baseUrl/api/student/results/$resultId/review');
    final response = await http.get(url, headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load review data');
    }
  }

  // --- Teacher / Exam Management Functions ---
  static Future<List<Map<String, dynamic>>> getTeacherExams() async {
    final headers = await _getAuthHeaders();
    final url = Uri.parse('$baseUrl/api/teacher/exams');
    final response = await http.get(url, headers: headers);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load teacher exams');
    }
  }

  static Future<http.Response> deleteTeacherExam(int examId) async {
    final headers = await _getAuthHeaders();
    final url = Uri.parse('$baseUrl/api/teacher/exams/$examId');
    return http.delete(url, headers: headers);
  }

  static Future<Map<String, dynamic>> getExamByCode(String code) async {
    final headers = await _getAuthHeaders();
    // URL từ ExamsController mới: /api/exams/...
    final url = Uri.parse('$baseUrl/api/exams/by-code/$code');
    final response = await http.get(url, headers: headers);
    if (response.statusCode == 200) { return jsonDecode(response.body); }
    else { throw Exception('Mã bài thi không tồn tại hoặc có lỗi.'); }
  }



  /// Lấy thông tin chi tiết của một bài thi
  static Future<Map<String, dynamic>> getExamDetails(int examId) async {
    final headers = await _getAuthHeaders(); // Cần token để xác thực
    final url = Uri.parse('$baseUrl/api/exams/$examId'); // Endpoint mới
    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Lỗi tải chi tiết bài thi. Status code: ${response.statusCode}');
    }
  }

  /// Lấy thông tin profile của user từ server
  static Future<Map<String, dynamic>> getUserProfile() async {
    final headers = await _getAuthHeaders();
    final response = await http.get(Uri.parse('$baseUrl/api/users/profile'), headers: headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load user profile');
    }
  }

  /// Cập nhật thông tin profile của user
  static Future<http.Response> updateUserProfile(Map<String, dynamic> userData) async {
    final headers = await _getAuthHeaders();
    return http.put(
      Uri.parse('$baseUrl/api/users/profile'),
      headers: headers,
      body: jsonEncode(userData),
    );
  }
  /// Kiểm tra xem mã bài thi đã tồn tại hay chưa
  static Future<bool> examCodeExists(String code) async {
    // Sửa lại URL để truyền đúng giá trị của biến code
    final url = Uri.parse('$baseUrl/api/exams/code-exists/$code');

    // Vì endpoint đã được cho phép truy cập công khai, chúng ta không cần gửi token
    final response = await http.get(url);

    if (response.statusCode == 200) {
      // Thêm 'as bool' để đảm bảo kiểu dữ liệu trả về là boolean
      return jsonDecode(response.body)['exists'] as bool;
    } else {
      // Ném ra lỗi với thông tin chi tiết hơn
      throw Exception('Lỗi kiểm tra mã bài thi. Status code: ${response.statusCode}');
    }
  }

  static Future<http.Response> createExam(Map<String, dynamic> examData) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(
      Uri.parse("$baseUrl/api/exams/create"),
      headers: headers,
      body: jsonEncode(examData),
    );
    // Trả về toàn bộ đối tượng response để UI có thể đọc statusCode và body
    return response;
  }

  static Future<void> updateExamById(int examId, Map<String, dynamic> examData) async {
    final headers = await _getAuthHeaders();
    final response = await http.put(
      Uri.parse('$baseUrl/api/exams/update/$examId'),
      headers: headers,
      body: jsonEncode(examData),
    );
    if (response.statusCode != 200) {
      throw Exception("Lỗi cập nhật bài thi");
    }
  }

  // --- Original Question/Answer Functions ---
  static Future<List<Map<String, dynamic>>> getQuestionsByExamId(int examId) async {
    final headers = await _getAuthHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/questions/by-exam/$examId'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load questions');
    }
  }

  static Future<List<Map<String, dynamic>>> getAnswersByQuestionId(int questionId) async {
    final headers = await _getAuthHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/answers/by-question/$questionId'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load answers');
    }
  }

  static Future<int> insertQuestionWithAnswers({
    required int examId,
    required String questionText,
    required Map<String, String> answers,
    required String correctAnswer,
  }) async {
    // SỬA LẠI: Lấy header có chứa token xác thực
    final headers = await _getAuthHeaders();
    final url = Uri.parse('$baseUrl/api/questions');

    final response = await http.post(
      url,
      headers: headers, // Gửi header đã được xác thực
      body: jsonEncode({
        'examId': examId,
        'questionText': questionText,
        'answers': answers,
        'correctAnswer': correctAnswer,
      }),
    );

    print('📥 Phản hồi từ API thêm câu hỏi: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic> && data.containsKey('id')) {
        return data['id'];
      }
      throw Exception("Phản hồi từ server không hợp lệ: $data");
    } else {
      throw Exception("Lỗi khi thêm câu hỏi: ${response.body}");
    }
  }

  static Future<void> updateQuestion({
    required int questionId,
    required int examId,
    required String questionText,
    required Map<String, String> answers,
    required String correctAnswer,
  }) async {
    // SỬA LẠI: Lấy header có chứa token xác thực
    final headers = await _getAuthHeaders();
    final url = Uri.parse('$baseUrl/api/questions/$questionId');

    final body = {
      'id': questionId,
      'examId': examId,
      'questionText': questionText,
      'answers': answers,
      'correctAnswer': correctAnswer,
    };

    final response = await http.put(
      url,
      headers: headers, // Gửi header đã được xác thực
      body: jsonEncode(body),
    );

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Lỗi cập nhật câu hỏi. Status: ${response.statusCode}');
    }
  }



  static Future<void> deleteQuestion(int questionId) async {
    // Lấy header xác thực để đảm bảo có quyền xóa
    final headers = await _getAuthHeaders();

    // SỬA LẠI URL CHO ĐÚNG
    final url = Uri.parse('$baseUrl/api/questions/$questionId');

    final response = await http.delete(
      url,
      headers: headers, // Gửi kèm token
    );

    // KIỂM TRA PHẢN HỒI TỪ SERVER
    // Server trả về 204 NoContent khi xóa thành công
    if (response.statusCode != 204) {
      throw Exception('Lỗi khi xóa câu hỏi. Mã lỗi: ${response.statusCode}');
    }
  }
}
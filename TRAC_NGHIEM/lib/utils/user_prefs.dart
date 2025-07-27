import 'package:shared_preferences/shared_preferences.dart';

class UserPrefs {
  // --- CÁC HÀM MỚI CẦN THÊM ---

  /// Lưu thông tin người dùng kèm id
  static Future<void> saveUserDataWithId({
    required int id,
    required String fullName,
    required String email,
    required String role,
    required String createdAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('id', id);
    await prefs.setString('fullName', fullName);
    await prefs.setString('email', email);
    await prefs.setString('role', role);
    await prefs.setString('createdAt', createdAt);
  }

  /// Lấy ID người dùng
  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('id');
  }

  /// Lấy toàn bộ thông tin người dùng (bao gồm id)
  static Future<Map<String, dynamic>?> getUserDataWithId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('id');
    if (id == null) return null;

    return {
      'id': id,
      'fullName': prefs.getString('fullName'),
      'email': prefs.getString('email'),
      'role': prefs.getString('role'),
      'avatar': prefs.getString('avatar'), // Thêm dòng này
    };
  }

// Thêm hàm để cập nhật avatar sau khi tải lên
  static Future<void> updateUserAvatar(String avatarUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('avatar', avatarUrl);
  }

  /// Lưu JWT Token
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  /// Lấy JWT Token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }


  // --- CÁC HÀM CŨ CỦA BẠN (GIỮ NGUYÊN) ---

  /// Lưu thông tin người dùng
  static Future<void> saveUserData(String fullName, String email, String role, String createdAt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fullName', fullName);
    await prefs.setString('email', email);
    await prefs.setString('role', role);
    await prefs.setString('createdAt', createdAt);
  }

  /// Lấy tên đầy đủ
  static Future<String?> getFullName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('fullName');
  }

  /// Lấy email (username)
  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('email');
  }

  /// Lấy vai trò
  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('role');
  }

  /// Lấy ngày tạo
  static Future<String?> getCreatedAt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('createdAt');
  }

  /// Xóa toàn bộ thông tin người dùng
  static Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    // CẬP NHẬT: Xóa cả các key mới để đảm bảo sạch sẽ
    await prefs.remove('id');
    await prefs.remove('jwt_token');
    await prefs.remove('fullName');
    await prefs.remove('email');
    await prefs.remove('role');
    await prefs.remove('createdAt');
  }
}
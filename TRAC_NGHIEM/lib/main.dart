import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/teacher_screen.dart';
import 'utils/user_prefs.dart';

// SỬA LẠI HÀM MAIN ĐỂ CÓ THỂ KIỂM TRA ĐĂNG NHẬP
void main() async {
  // Đảm bảo các thành phần của Flutter đã sẵn sàng trước khi chạy app
  WidgetsFlutterBinding.ensureInitialized();

  // Lấy token và vai trò người dùng đã lưu
  final String? token = await UserPrefs.getToken();
  final Map<String, dynamic>? user = await UserPrefs.getUserDataWithId();
  final String? role = user?['role'];

  Widget initialScreen;

  // Quyết định màn hình khởi đầu dựa trên thông tin đăng nhập
  if (token != null && role != null) {
    // Nếu có token và vai trò, điều hướng đến màn hình tương ứng
    if (role == 'teacher') {
      initialScreen = const TeacherScreen();
    } else {
      initialScreen = const HomeScreen();
    }
  } else {
    // Nếu không, hiển thị màn hình đăng nhập
    initialScreen = const LoginScreen();
  }

  runApp(MyApp(initialScreen: initialScreen));
}

class MyApp extends StatelessWidget {
  final Widget initialScreen;

  const MyApp({required this.initialScreen, super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ứng dụng trắc nghiệm',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto', // Bạn có thể thay đổi font chữ ở đây
      ),
      debugShowCheckedModeBanner: false,
      // Màn hình khởi đầu được quyết định bởi logic trong hàm main
      home: initialScreen,
    );
  }
}

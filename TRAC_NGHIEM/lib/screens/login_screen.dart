import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_screen.dart';
import 'register_screen.dart';
import 'login_help_screen.dart';
import 'teacher_screen.dart';
import '../utils/user_prefs.dart';
import '../services/api_service.dart';
import 'dart:convert';
import 'dart:math' as math;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // Các controller và state cho UI và animation
  late final AnimationController _controller;
  late final Animation<double> _rotationAnimation;
  late final AnimationController _appleController;
  late final Animation<Offset> _appleSlideAnimation;
  late final AnimationController _waveController;
  late final AnimationController _tiltController;
  bool isBusiness = false;
  final TextEditingController domainController = TextEditingController();
  bool _obscureText = true;

  @override
  void initState() {
    super.initState();
    // Phần code animation giữ nguyên
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _rotationAnimation = Tween<double>(begin: -0.05, end: 0.05).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _appleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
    _appleSlideAnimation = Tween<Offset>(begin: const Offset(0, -0.05), end: const Offset(0, 0.05)).animate(CurvedAnimation(parent: _appleController, curve: Curves.easeInOut));
    _waveController = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    _tiltController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    _controller.dispose();
    _appleController.dispose();
    _waveController.dispose();
    _tiltController.dispose();
    super.dispose();
  }

  // HÀM XỬ LÝ ĐĂNG NHẬP MỚI
  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final email = emailController.text.trim();
      final password = passwordController.text.trim();

      try {
        // Gọi hàm login từ ApiService
        final response = await ApiService.login(email, password);

        Navigator.of(context).pop(); // Tắt loading

        if (response.statusCode == 200 && mounted) {
          final data = jsonDecode(response.body);

          final token = data['token'] as String;
          final user = data['user'] as Map<String, dynamic>;

          // LƯU TOKEN VÀ DỮ LIỆU USER
          await UserPrefs.saveToken(token);
          await UserPrefs.saveUserDataWithId(
            id: user['id'],
            fullName: user['fullName'],
            email: user['email'],
            role: user['role'],
            createdAt: DateTime.now().toIso8601String(), // Nên lấy từ server nếu có
          );

          if (user['role'] == 'teacher') {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const TeacherScreen()));
          } else {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email hoặc mật khẩu không đúng')));
        }
      } catch (e) {
        Navigator.of(context).pop(); // Tắt loading
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi kết nối: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/bg_login.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 80),
                  Column(
                    children: [
                      Image.asset(
                        'assets/images/azota_logo.png',
                        width: 60,
                      ),
                      const SizedBox(height: 12),
                      AnimatedBuilder(
                        animation: _waveController,
                        builder: (context, child) {
                          return ShaderMask(
                            shaderCallback: (Rect bounds) {
                              return LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  for (double i = 0; i <= 1; i += 0.1)
                                    Color.fromARGB(
                                      ((0.5 + 0.5 *
                                          (math.sin((- _waveController.value * 2 * math.pi) + i * 10))
                                      ) * 255).toInt(),
                                      0, 51, 102, // RGB cho màu #003366
                                    )
                                ],
                                stops: [for (double i = 0; i <= 1; i += 0.1) i],
                              ).createShader(bounds);
                            },
                            blendMode: BlendMode.srcATop,
                            child: Text(
                              "Đăng nhập",
                              style: GoogleFonts.roboto(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white, // màu mặc định để lộ Shader
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 120),
                  TextFormField(
                    controller: emailController,
                    decoration: InputDecoration(
                      hintText: 'Email, số điện thoại hoặc tên tài khoản',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vui lòng nhập email/tài khoản';
                      }
                      if (!value.contains('@')) {
                        return 'Email không hợp lệ';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    obscureText: _obscureText,
                    controller: passwordController,
                    decoration: InputDecoration(
                      hintText: 'Nhập mật khẩu',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureText ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureText = !_obscureText;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (value) =>
                    value == null || value.isEmpty ? 'Vui lòng nhập mật khẩu' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const LoginHelpScreen()),
                          );
                        },
                        child: Text(
                          "Quên mật khẩu",
                          style: TextStyle(
                            color: Colors.blue[800], // Đổi màu cho giống link
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff0052CC),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _handleLogin,
                          child: const Text("Đăng nhập"),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const RegisterScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[800],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text("Đăng ký"),
                    ),
                  ),
                  const SizedBox(height: 120),
                  const SizedBox(height: 180),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _tiltController,
                        builder: (context, child) {
                          final text = "student-mobile-web.tracnghiem.vn";
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(text.length, (index) {
                              final char = text[index];
                              final angle = 0.1 * math.sin(_tiltController.value * 2 * math.pi + index * 0.3);
                              return Transform.rotate(
                                angle: angle,
                                child: Text(
                                  char,
                                  style: const TextStyle(
                                    color: Color(0xff0033CC),
                                    fontWeight: FontWeight.bold,
                                    fontStyle: FontStyle.italic,
                                    fontSize: 16,
                                  ),
                                ),
                              );
                            }),
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      Image.asset("assets/images/vn_flag.png", width: 24),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
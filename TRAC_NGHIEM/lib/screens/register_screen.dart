import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;
import 'dart:convert';
import '../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with TickerProviderStateMixin {
  // --- Thêm các controller và biến state mới ---
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  String _selectedRole = 'student';
  String? _selectedGender = 'Nam';

  // State để hiện/ẩn mật khẩu
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // --- Animation Controllers (giữ nguyên) ---
  late final AnimationController _controller;
  late final Animation<double> _rotationAnimation;
  late final AnimationController _appleController;
  late final Animation<Offset> _appleSlideAnimation;
  late final AnimationController _waveController;
  late final AnimationController _tiltController;

  @override
  void initState() {
    super.initState();
    // Khởi tạo animation (giữ nguyên)
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _rotationAnimation = Tween<double>(begin: -0.05, end: 0.05).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _appleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
    _appleSlideAnimation = Tween<Offset>(begin: const Offset(0, -0.05), end: const Offset(0, 0.05)).animate(CurvedAnimation(parent: _appleController, curve: Curves.easeInOut));
    _waveController = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    _tiltController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat();
  }

  @override
  void dispose() {
    // Thêm các controller mới vào dispose
    fullNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    phoneController.dispose();
    _controller.dispose();
    _appleController.dispose();
    _waveController.dispose();
    _tiltController.dispose();
    super.dispose();
  }

  // --- HÀM registerUser ĐÃ ĐƯỢC CẬP NHẬT ---
  Future<void> registerUser() async {
    if (_formKey.currentState!.validate()) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final userData = {
        'fullName': fullNameController.text.trim(),
        'email': emailController.text.trim(),
        'password': passwordController.text.trim(),
        'role': _selectedRole,
        'phone': phoneController.text.trim(),
        'gender': _selectedGender,
      };

      try {
        // Gọi hàm register từ ApiService
        final response = await ApiService.register(userData);

        Navigator.of(context).pop(); // Tắt loading

        if (response.statusCode == 200 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Đăng ký thành công! Vui lòng đăng nhập.")),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        } else {
          final error = jsonDecode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Lỗi: $error")),
          );
        }
      } catch (e) {
        Navigator.of(context).pop(); // Tắt loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi kết nối: ${e.toString()}")),
        );
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
                  const SizedBox(height: 50),
                  Column(
                    children: [
                      Image.asset('assets/images/azota_logo.png', width: 60),
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
                                      0, 51, 102,
                                    )
                                ],
                                stops: [for (double i = 0; i <= 1; i += 0.1) i],
                              ).createShader(bounds);
                            },
                            blendMode: BlendMode.srcATop,
                            child: Text(
                              "Đăng ký",
                              style: GoogleFonts.roboto(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 50),
                  TextFormField(
                    controller: fullNameController,
                    decoration: _buildInputDecoration('Họ tên'),
                    validator: (value) => value == null || value.isEmpty ? 'Vui lòng nhập họ tên' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailController,
                    decoration: _buildInputDecoration('Email'),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Vui lòng nhập email';
                      if (!value.contains('@')) return 'Email không hợp lệ';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phoneController,
                    decoration: _buildInputDecoration('Số điện thoại'),
                    keyboardType: TextInputType.phone,
                    validator: (value) => value == null || value.isEmpty ? 'Vui lòng nhập số điện thoại' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    obscureText: _obscurePassword,
                    decoration: _buildInputDecoration(
                      'Nhập mật khẩu',
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (value) => value != null && value.length < 6 ? 'Mật khẩu tối thiểu 6 ký tự' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: _buildInputDecoration(
                      'Nhập lại mật khẩu',
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Vui lòng nhập lại mật khẩu';
                      if (value != passwordController.text) return 'Mật khẩu không khớp';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Giới tính:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                      Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              title: const Text("Nam"),
                              leading: Radio<String>(
                                value: 'Nam',
                                groupValue: _selectedGender,
                                onChanged: (value) => setState(() => _selectedGender = value),
                              ),
                            ),
                          ),
                          Expanded(
                            child: ListTile(
                              title: const Text("Nữ"),
                              leading: Radio<String>(
                                value: 'Nữ',
                                groupValue: _selectedGender,
                                onChanged: (value) => setState(() => _selectedGender = value),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Chọn vai trò:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                      Row(
                        children: [
                          Expanded(
                      child: ListTile(
                      title: const Text("Học sinh"),
                      leading: Radio<String>(
                        value: 'student',
                        groupValue: _selectedRole,
                        onChanged: (value) => setState(() => _selectedRole = value!),
                      ),
            ),
          ),
                          Expanded(
                            child: ListTile(
                              title: const Text("Giáo viên"),
                              leading: Radio<String>(
                                value: 'teacher',
                                groupValue: _selectedRole,
                                onChanged: (value) => setState(() => _selectedRole = value!),
                              ),
                            ),
                          ),
                        ]
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: registerUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff0052CC),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text("Đăng ký"),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[800],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const LoginScreen()),
                        );
                      },
                      child: const Text("Đăng nhập"),
                    ),
                  ),
                  const SizedBox(height: 40),

                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _tiltController,
                        builder: (context, child) {
                          final text = "student-mobile-web.azota.vn";
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

  InputDecoration _buildInputDecoration(String hint, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
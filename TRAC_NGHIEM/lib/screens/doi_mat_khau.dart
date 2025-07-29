import 'package:flutter/material.dart';
import '../services/api_service.dart'; // Sử dụng ApiService
import 'dang_nhap.dart';
import 'dart:convert';

class LoginHelpScreen extends StatefulWidget {
  const LoginHelpScreen({Key? key}) : super(key: key);

  @override
  State<LoginHelpScreen> createState() => _LoginHelpScreenState();
}

class _LoginHelpScreenState extends State<LoginHelpScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  bool _obscureText = true;
  bool _isLoading = false;

  // Animation Controllers
  late final AnimationController _controller;
  late final Animation<double> _rotationAnimation;
  late final AnimationController _appleController;
  late final Animation<Offset> _appleSlideAnimation;

  @override
  void initState() {
    super.initState();
    // Khởi tạo animations
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _rotationAnimation = Tween<double>(begin: -0.05, end: 0.05).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _appleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
    _appleSlideAnimation = Tween<Offset>(begin: const Offset(0, -0.05), end: const Offset(0, 0.05)).animate(CurvedAnimation(parent: _appleController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _newPasswordController.dispose();
    _controller.dispose();
    _appleController.dispose();
    super.dispose();
  }

  // HÀM _resetPassword
  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final newPassword = _newPasswordController.text;

    try {
      final response = await ApiService.resetPassword(email, newPassword);

      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Đổi mật khẩu thành công! Vui lòng đăng nhập lại.")),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
        );
      } else {
        final error = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi: $error")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi kết nối: ${e.toString()}")),
        );
      }
    } finally {
      if(mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text("Quên mật khẩu", style: TextStyle(color: Colors.black)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 1,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Image.asset("assets/images/vn_flag.png", width: 28, height: 25, fit: BoxFit.contain),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "Email đã đăng ký",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || !value.contains('@')) return 'Vui lòng nhập email hợp lệ';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _newPasswordController,
                obscureText: _obscureText,
                decoration: InputDecoration(
                    labelText: "Mật khẩu mới",
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscureText = !_obscureText),
                    )
                ),
                validator: (value) {
                  if (value == null || value.length < 6) return 'Mật khẩu mới phải ít nhất 6 ký tự';
                  return null;
                },
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _resetPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff0052CC),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                      : const Text("Đặt lại mật khẩu", style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
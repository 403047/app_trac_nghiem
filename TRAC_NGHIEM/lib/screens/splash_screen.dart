import 'package:flutter/material.dart';
import 'login_screen.dart'; // Hoặc bất kỳ màn hình chính nào của bạn

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // Chuyển sang màn hình đăng nhập sau 3 giây
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/bg_splash.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 150), // 👈 khoảng cách từ top xuống
            Center(
              child: Column(
                children: [
                  Image.asset(
                    "assets/images/azota_logo.png",
                    width: 100,
                    height: 100,
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    "TRẮC NGHIỆM 4.0",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(), // 👈 đẩy phần còn lại xuống dưới (nếu cần)
          ],
        ),
      ),
    );
  }
}

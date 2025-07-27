import 'package:flutter/material.dart';
import '../login_screen.dart';
import '../../services/api_service.dart';
import '../../utils/user_prefs.dart';
import 'dart:convert';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  // HÀM XỬ LÝ XÓA TÀI KHOẢN ĐÃ ĐƯỢC CẬP NHẬT
  void _handleDeleteAccount() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Xác nhận xoá tài khoản"),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Để xác nhận, vui lòng nhập mật khẩu hiện tại của bạn. Hành động này không thể hoàn tác."),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Huỷ"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                Navigator.pop(context); // Đóng dialog
                _confirmDeletion();
              }
            },
            child: const Text("Xoá Vĩnh Viễn", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeletion() async {
    setState(() => _isLoading = true);
    final password = _passwordController.text;

    try {
      final response = await ApiService.deleteAccount(password);

      if (response.statusCode == 200 && mounted) {
        await UserPrefs.clearUserData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Tài khoản đã được xoá thành công.")),
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
    } catch(e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi kết nối: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Xoá tài khoản"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Xoá tài khoản",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              "Nếu bạn chắc chắn muốn xoá tài khoản vĩnh viễn, vui lòng bấm nút \"Xác nhận\" bên dưới.",
              style: TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 120,
              height: 45,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleDeleteAccount,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white))
                    : const Text("Xác nhận"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
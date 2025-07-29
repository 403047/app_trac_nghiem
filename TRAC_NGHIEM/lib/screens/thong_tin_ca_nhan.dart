import 'dart:io';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/user_prefs.dart';
import '../utils/image_helper.dart';
import 'settings_profile/thong_bao.dart';
import 'dang_nhap.dart';
import 'settings_profile/doi_mat_khau.dart';
import 'settings_profile/xoa_tai_khoan.dart';
import 'dart:convert';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  String? fullName = '';
  String? email = '';
  String? role;
  String? avatarUrl;
  File? _selectedImage;

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String? _gender = "Nam";

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final userData = await ApiService.getUserProfile();
      if (mounted) {
        setState(() {
          fullName = userData['fullName'];
          email = userData['email'];
          role = userData['role'];
          avatarUrl = userData['avatar'];
          _fullNameController.text = userData['fullName'] ?? '';
          _phoneController.text = userData['phone'] ?? '';
          _gender = userData['gender'] ?? 'Nam';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Lỗi tải thông tin cá nhân: ${e.toString()}"))
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage() async {
    final imageFile = await ImageHelper.pickImage();
    if (imageFile != null) {
      setState(() {
        _selectedImage = imageFile;
        _isLoading = true; // Bắt đầu loading khi tải ảnh
      });

      try {
        final response = await ApiService.uploadAvatar(imageFile);
        if (response.statusCode == 200 && mounted) {
          final data = jsonDecode(response.body);
          setState(() {
            avatarUrl = data['path'];
            _selectedImage = null; // Bỏ ảnh xem trước
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Cập nhật ảnh đại diện thành công!")),
          );
        } else {
          throw Exception("Lỗi từ server: ${response.body}");
        }
      } catch (e) {
        if(mounted) {
          setState(() => _selectedImage = null);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Tải ảnh thất bại: ${e.toString()}")),
          );
        }
      } finally {
        if(mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _handleUpdateProfile() async {
    final updatedData = {
      'fullName': _fullNameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'gender': _gender,
    };

    try {
      final response = await ApiService.updateUserProfile(updatedData);
      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cập nhật thông tin thành công!")),
        );
        await _loadUserData();
      } else {
        throw Exception("Lỗi từ server: ${response.body}");
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi cập nhật: ${e.toString()}")),
        );
      }
    }
  }

  Future<void> _showChangeEmailDialog() async {
    final newEmailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Đổi địa chỉ Email'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: ListBody(
                children: <Widget>[
                  const Text('Để bảo mật, vui lòng nhập mật khẩu hiện tại của bạn.'),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: newEmailController,
                    decoration: const InputDecoration(labelText: 'Email mới', border: OutlineInputBorder()),
                    validator: (value) {
                      if (value == null || !value.contains('@')) return 'Vui lòng nhập email hợp lệ';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Mật khẩu hiện tại', border: OutlineInputBorder()),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Hủy'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            FilledButton(
              child: const Text('Xác nhận'),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final newEmail = newEmailController.text.trim();
                  final password = passwordController.text.trim();

                  try {
                    final response = await ApiService.updateUserEmail(newEmail, password);
                    if (response.statusCode == 200 && mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Đổi email thành công! Vui lòng đăng nhập lại.")),
                      );
                      await UserPrefs.clearUserData();
                      Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
                    } else {
                      final error = jsonDecode(response.body);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: $error")));
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi kết nối: ${e.toString()}")));
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text("Cài đặt tài khoản", style: TextStyle(color: Colors.black)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Image.asset("assets/images/vn_flag.png", width: 28, height: 25, fit: BoxFit.contain),
          ),
          if (role == 'student')
            IconButton(
              icon: const Icon(Icons.notifications_none, color: Colors.black87),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationScreen()));
              },
            ),
          const SizedBox(width: 10),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  const ListTile(leading: Icon(Icons.person, color: Colors.blue), title: Text("Chung"), tileColor: Color(0xffE0ECFF)),
                  ListTile(leading: const Icon(Icons.lock_outline), title: const Text("Đổi mật khẩu"), onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const ChangePasswordScreen()));
                  }),
                  ListTile(leading: const Icon(Icons.delete_outline), title: const Text("Xoá tài khoản"), onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const DeleteAccountScreen()));
                  }),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text("Đăng xuất", style: TextStyle(color: Colors.red)),
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text("Xác nhận đăng xuất"),
                          content: const Text("Bạn có chắc chắn muốn đăng xuất không?"),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Hủy")),
                            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Đăng xuất")),
                          ],
                        ),
                      );

                      if (confirm == true && mounted) {
                        await UserPrefs.clearUserData();
                        // Trả về tín hiệu 'LOGGED_OUT' khi đóng màn hình
                        Navigator.of(context).pop('LOGGED_OUT');
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundImage: _selectedImage != null
                            ? FileImage(_selectedImage!)
                            : (avatarUrl != null && avatarUrl!.isNotEmpty
                            ? NetworkImage(ApiService.baseUrl + avatarUrl!)
                            : null) as ImageProvider?,
                        backgroundColor: Colors.grey.shade300,
                        child: (_selectedImage == null && (avatarUrl == null || avatarUrl!.isEmpty))
                            ? Text(
                          (fullName != null && fullName!.isNotEmpty) ? fullName![0].toUpperCase() : "?",
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                        )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.upload, size: 16),
                            label: const Text("Tải lên"),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xffE8F0FE), foregroundColor: Colors.blue, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), textStyle: const TextStyle(fontSize: 14)),
                          ),
                          const SizedBox(height: 4),
                          const Text("Tải lên file ảnh và kích thước tối đa 5MB", style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 24),
                  Align(alignment: Alignment.centerLeft, child: Text("Họ và tên", style: TextStyle(color: Colors.grey[700]))),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _fullNameController,
                    decoration: InputDecoration(hintText: 'Nhập họ và tên', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                  const SizedBox(height: 16),
                  Align(alignment: Alignment.centerLeft, child: Text("Email", style: TextStyle(color: Colors.grey[700]))),
                  const SizedBox(height: 4),
                  TextFormField(
                    key: Key(email ?? ''),
                    initialValue: email,
                    readOnly: true,
                    decoration: const InputDecoration(filled: true, fillColor: Color(0xffE9EDF5), border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: _showChangeEmailDialog,
                      child: const Text("Click vào đây để đổi email", style: TextStyle(color: Colors.blue, fontSize: 13, decoration: TextDecoration.underline)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(alignment: Alignment.centerLeft, child: Text("Số điện thoại", style: TextStyle(color: Colors.grey[700]))),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(hintText: "Nhập số điện thoại...", border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  Align(alignment: Alignment.centerLeft, child: Text("Giới tính", style: TextStyle(color: Colors.grey[700]))),
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text("Nam"),
                          leading: Radio<String>(
                            value: "Nam",
                            groupValue: _gender,
                            onChanged: (val) => setState(() => _gender = val),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text("Nữ"),
                          leading: Radio<String>(
                            value: "Nữ",
                            groupValue: _gender,
                            onChanged: (val) => setState(() => _gender = val),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _handleUpdateProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff0052CC),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text("Cập nhật", style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
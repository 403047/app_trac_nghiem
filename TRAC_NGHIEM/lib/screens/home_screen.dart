import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../utils/user_prefs.dart';
import 'exam_detail_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';
import 'settings_profile/notification_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> incompleteExams = [];
  List<Map<String, dynamic>> expiredExams = [];
  List<Map<String, dynamic>> recentHistory = [];
  String username = "";
  int? userId;
  String? avatarUrl; // THÊM BIẾN ĐỂ LƯU AVATAR
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  /// Tải dữ liệu người dùng và danh sách bài thi lần đầu
  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
    });

    // SỬA LẠI: Lấy thông tin người dùng mới nhất từ API để đảm bảo đồng bộ
    try {
      final user = await ApiService.getUserProfile();
      if (!mounted) return;

      setState(() {
        userId = user['id'] as int?;
        username = user['fullName'] as String? ?? '';
        avatarUrl = user['avatar'] as String?; // Lấy avatarUrl
      });

      // Lưu lại thông tin mới nhất vào UserPrefs để dùng offline
      await UserPrefs.saveUserDataWithId(
        id: userId!,
        fullName: username,
        email: user['email'] ?? '',
        role: user['role'] ?? '',
        createdAt: user['createdAt'] ?? DateTime.now().toIso8601String(),
      );
      if (avatarUrl != null) {
        await UserPrefs.updateUserAvatar(avatarUrl!);
      }

    } catch (e) {
      // Nếu lỗi API, thử lấy từ cache (dữ liệu cũ hơn)
      final user = await UserPrefs.getUserDataWithId();
      if (user != null && mounted) {
        setState(() {
          userId = user['id'] as int?;
          username = user['fullName'] as String? ?? '';
          avatarUrl = user['avatar'] as String?;
        });
      }
    }

    // Tải danh sách các bài thi từ API
    await _fetchExamsFromApi();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Hàm riêng để gọi API và cập nhật danh sách bài thi
  Future<void> _fetchExamsFromApi() async {
    try {
      final results = await Future.wait([
        ApiService.getExamsByStatus('unfinished'),
        ApiService.getExamsByStatus('expired'),
        ApiService.getExamsByStatus('submitted'),
      ]);

      if (mounted) {
        setState(() {
          incompleteExams = results[0];
          expiredExams = results[1];
          recentHistory = results[2];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi tải danh sách bài thi: ${e.toString()}")),
        );
      }
    }
  }

  /// Xử lý khi người dùng nhấn nút thêm bài thi bằng mã
  Future<void> _onAddPressed() async {
    final code = await _askForCode();
    if (code == null || code.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final exam = await ApiService.getExamByCode(code);
      final examId = exam['id'] as int;
      String? examPassword = exam['password'] as String?;

      String? inputPassword;
      if (examPassword != null && examPassword.isNotEmpty) {
        inputPassword = await _askForPassword();
        if (inputPassword == null) {
          setState(() => _isLoading = false);
          return;
        }
      }

      final response = await ApiService.addExamToUser(
        examId: examId,
        password: inputPassword,
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Đã thêm bài thi thành công!")),
        );
        await _fetchExamsFromApi();
      } else if (response.statusCode == 401) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Mật khẩu không đúng.")),
        );
      } else if (response.statusCode == 409) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bài thi này đã có trong danh sách của bạn.")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi: ${response.body}")),
        );
      }
    } catch (e) {
      debugPrint('>>> LỖI KẾT NỐI API: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Mã bài thi không tồn tại hoặc có lỗi xảy ra.")),
        );
      }
    } finally {
      if(mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<String?> _askForCode() {
    String? code;
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Nhập mã bài thi"),
        content: TextField(
          onChanged: (v) => code = v.trim(),
          decoration: const InputDecoration(hintText: "Mã đề thi"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Hủy")),
          TextButton(onPressed: () => Navigator.pop(context, code), child: const Text("Tìm")),
        ],
      ),
    );
  }

  Future<String?> _askForPassword() {
    String? pwd;
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Nhập mật khẩu đề thi"),
        content: TextField(
          onChanged: (v) => pwd = v,
          obscureText: true,
          decoration: const InputDecoration(hintText: "Mật khẩu"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Hủy")),
          TextButton(onPressed: () => Navigator.pop(context, pwd), child: const Text("OK")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Image.asset("assets/images/vn_flag.png", width: 28, height: 25),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black87),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationScreen()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () async { // Chuyển thành async
                // Chờ kết quả trả về từ ProfileScreen
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );

                // Kiểm tra kết quả
                if (result == 'LOGGED_OUT' && mounted) {
                  // Nếu đã đăng xuất, điều hướng về trang Login
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                        (route) => false,
                  );
                } else {
                  // Nếu không, chỉ cần tải lại dữ liệu (ví dụ: cập nhật avatar)
                  _loadInitialData();
                }
              },
              child: CircleAvatar(
                backgroundColor: Colors.grey.shade300,
                backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty)
                    ? NetworkImage(ApiService.baseUrl + avatarUrl!)
                    : null,
                child: (avatarUrl == null || avatarUrl!.isEmpty)
                    ? Text(
                  username.isNotEmpty ? username.split(' ').last.characters.first.toUpperCase() : '',
                  style: const TextStyle(color: Colors.black),
                )
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _fetchExamsFromApi,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionTitle(title: "Đề thi chưa hoàn thành"),
            if (incompleteExams.isEmpty)
              const EmptyMessage(message: "Hiện chưa có đề thi nào."),
            ...incompleteExams.map((exam) => ExamCard(
              exam: exam,
              onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExamDetailScreen(exam: exam))).then((_) => _fetchExamsFromApi()),
              actionIcon: Icons.play_arrow,
              actionLabel: "Làm bài",
            )),
            const SizedBox(height: 24),
            const SectionTitle(title: "Đề thi đã hết hạn"),
            if (expiredExams.isEmpty)
              const EmptyMessage(message: "Không có đề thi đã hết hạn."),
            ...expiredExams.map((exam) => ExamCard(
              exam: exam,
              onAction: () {},
              actionIcon: Icons.lock_clock,
              actionLabel: "Hết hạn",
            )),
            const SizedBox(height: 24),
            const SectionTitle(title: "Lịch sử làm bài / Nộp bài"),
            if (recentHistory.isEmpty)
              const EmptyMessage(message: "Chưa có lịch sử làm bài."),
            ...recentHistory.map((exam) => ExamCard(
              exam: exam,
              onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExamDetailScreen(exam: exam))).then((_) => _fetchExamsFromApi()),
              actionIcon: Icons.check_circle_outline,
              actionLabel: "Xem lại",
            )),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xff0052CC),
        foregroundColor: Colors.white,
        onPressed: _onAddPressed,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// --- CÁC WIDGET PHỤ KHÔNG THAY ĐỔI ---

class SectionTitle extends StatelessWidget {
  final String title;
  const SectionTitle({required this.title, super.key});
  @override
  Widget build(BuildContext context) {
    return Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, height: 1.8));
  }
}

class EmptyMessage extends StatelessWidget {
  final String message;
  const EmptyMessage({required this.message, super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.black54))),
        ],
      ),
    );
  }
}

class ExamCard extends StatelessWidget {
  final Map<String, dynamic> exam;
  final VoidCallback onAction;
  final IconData actionIcon;
  final String actionLabel;

  const ExamCard({
    required this.exam,
    required this.onAction,
    required this.actionIcon,
    required this.actionLabel,
    super.key,
  });

  String _formatDateTime(String? dateTimeString) {
    if (dateTimeString == null || dateTimeString.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(dateTimeString);
      return DateFormat('dd/MM/yyyy - HH:mm').format(dt);
    } catch (_) {
      return dateTimeString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(exam['title'] ?? 'Không có tiêu đề', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text("Hạn nộp: ${_formatDateTime(exam['deadline'] as String?)}"),
            const SizedBox(height: 8),
            Text("Thời gian làm bài: ${exam['duration']} phút"),
            const SizedBox(height: 8),
            Text("Số câu hỏi: ${exam['questionCount'] ?? 0}"),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon, size: 18),
                label: Text(actionLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff0052CC),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
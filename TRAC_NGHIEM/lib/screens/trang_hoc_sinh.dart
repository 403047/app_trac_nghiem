import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../utils/user_prefs.dart';
import 'chi_tiet_bai_thi.dart';
import 'thong_tin_ca_nhan.dart';
import 'dang_nhap.dart';
import 'settings_profile/thong_bao.dart';

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

  Future<void> _onAddPressed() async {
    String? code;

    while (true) {
      code = await _askForCode();

      if (code == null) return;

      if (code.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Vui lòng nhập mã bài thi.")),
          );
        }
        continue;
      }

      setState(() => _isLoading = true);

      Map<String, dynamic>? exam;

      try {
        exam = await ApiService.getExamByCode(code);
      } catch (e) {
        code = await _askForCode(showInvalidCodeError: true);
        setState(() => _isLoading = false);
        continue;
      }

      final examId = exam['id'] as int;
      final examPassword = exam['password'] as String?;

      // 👉 Thử thêm bài thi ngay lập tức nếu không có mật khẩu
      if (examPassword == null || examPassword.isEmpty) {
        final response = await ApiService.addExamToUser(examId: examId, password: null);

        setState(() => _isLoading = false);

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Đã thêm bài thi thành công!")),
          );
          await _fetchExamsFromApi();
        } else if (response.statusCode == 409) {
          // Bài thi đã có → báo lỗi ngay
          await _showAlreadyAddedDialog();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Lỗi từ server: ${response.body}")),
          );
        }

        return;
      }

      // Nếu có mật khẩu → kiểm tra tồn tại trước khi hỏi
      final checkResponse = await ApiService.addExamToUser(
        examId: examId,
        password: '',
      );

      if (checkResponse.statusCode == 409) {
        setState(() => _isLoading = false);
        await _showAlreadyAddedDialog();
        return;
      }

      // Nếu chưa tồn tại → tiến hành hỏi mật khẩu
      int retryCount = 0;
      bool success = false;

      while (retryCount < 5 && !success) {
        final inputPassword = await _askForPasswordWithRetry(retryCount);


        if (inputPassword == null) break;

        final response = await ApiService.addExamToUser(
          examId: examId,
          password: inputPassword,
        );

        if (response.statusCode == 200) {
          success = true;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Đã thêm bài thi thành công!")),
            );
            await _fetchExamsFromApi();
          }
        } else if (response.statusCode == 401) {
          retryCount++;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Lỗi từ server: ${response.body}")),
          );
          break;
        }
      }

      if (!success && retryCount >= 5) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bạn đã nhập sai mật khẩu quá 5 lần.")),
        );
      }

      setState(() => _isLoading = false);
      return;
    }
  }

  Future<void> _showAlreadyAddedDialog() async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Bài thi đã tồn tại"),
        content: const Text("Bài thi này đã có trong danh sách của bạn."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<String?> _askForCode({bool showInvalidCodeError = false}) {
    final TextEditingController controller = TextEditingController();
    bool showEmptyError = false;
    bool showInvalidError = showInvalidCodeError;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Nhập mã bài thi"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: "Mã đề thi",
                      errorText: showEmptyError
                          ? "Vui lòng nhập mã đề thi"
                          : showInvalidError
                          ? "Mã không đúng hoặc không tồn tại"
                          : null,
                    ),
                    onChanged: (_) {
                      if (showEmptyError || showInvalidError) {
                        setState(() {
                          showEmptyError = false;
                          showInvalidError = false;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Hủy"),
                ),
                TextButton(
                  onPressed: () {
                    final code = controller.text.trim();
                    if (code.isEmpty) {
                      setState(() {
                        showEmptyError = true;
                        showInvalidError = false;
                      });
                    } else {
                      Navigator.pop(context, code);
                    }
                  },
                  child: const Text("Tìm"),
                ),
              ],
            );
          },
        );
      },
    );
  }


  Future<String?> _askForPasswordWithRetry(int retryCount) {
    final TextEditingController controller = TextEditingController();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Nhập mật khẩu đề thi"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    obscureText: true,
                    decoration: const InputDecoration(hintText: "Mật khẩu"),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (retryCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        "Mật khẩu không đúng. Số lần nhập ${retryCount}/5",
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Hủy"),
                ),
                TextButton(
                  onPressed: controller.text.isNotEmpty
                      ? () => Navigator.pop(context, controller.text)
                      : null,
                  child: const Text("OK"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false, // bỏ nút back
        title: Text("Xin chào, $username", style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
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
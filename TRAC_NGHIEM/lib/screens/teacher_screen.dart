import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'profile_screen.dart';
import 'settings_profile/notification_screen.dart';
import 'create_exam_screen.dart';
import 'package:intl/intl.dart';
import '../utils/user_prefs.dart';
import '../services/api_service.dart';
import 'exam_results_screen.dart';
import 'login_screen.dart'; // THÊM IMPORT NÀY

class TeacherScreen extends StatefulWidget {
  const TeacherScreen({super.key});

  @override
  State<TeacherScreen> createState() => _TeacherScreenState();
}

class _TeacherScreenState extends State<TeacherScreen> {
  String username = "";
  String? avatarUrl;
  List<Map<String, dynamic>> _exams = [];
  bool _isLoading = true;
  bool _snackShown = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    // Tải thông tin người dùng và bài thi song song để nhanh hơn
    await Future.wait([
      _loadUserInfo(),
      _loadExams(),
    ]);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUserInfo() async {
    try {
      final user = await ApiService.getUserProfile();
      if (mounted) {
        setState(() {
          username = user['fullName'] ?? "Giáo viên";
          avatarUrl = user['avatar'];
        });
        // Cập nhật lại cache trong UserPrefs
        await UserPrefs.saveUserDataWithId(
            id: user['id'],
            fullName: user['fullName'],
            email: user['email'],
            role: user['role'],
            createdAt: user['createdAt']);
        if (avatarUrl != null) {
          await UserPrefs.updateUserAvatar(avatarUrl!);
        }
      }
    } catch (e) {
      // Nếu lỗi API, dùng dữ liệu cũ từ cache
      final user = await UserPrefs.getUserDataWithId();
      if (mounted && user != null) {
        setState(() {
          username = user['fullName'] ?? "Giáo viên";
          avatarUrl = user['avatar'];
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_snackShown) {
      final message = ModalRoute.of(context)?.settings.arguments as String?;
      if (message != null && message.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text(message)),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          );
        });
        _snackShown = true;
      }
    }
  }

  Future<void> _loadExams() async {
    try {
      final exams = await ApiService.getTeacherExams();
      if (mounted) {
        setState(() {
          _exams = exams;
        });
      }
    } catch (e) {
      // Không hiển thị lỗi nếu người dùng đã đăng xuất
      final token = await UserPrefs.getToken();
      if (mounted && token != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi tải danh sách bài thi: ${e.toString()}")),
        );
      }
    }
  }

  Future<void> _deleteExam(int examId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Xác nhận xoá"),
        content: const Text("Bạn có chắc muốn xoá bài thi này không? Thao tác này không thể hoàn tác."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Huỷ")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Xoá", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final response = await ApiService.deleteTeacherExam(examId);

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Đã xoá bài thi thành công.")),
        );
        _loadExams();
      }
      // Xử lý trường hợp không cho phép xóa (Conflict)
      else if (response.statusCode == 409) {
        // Lấy thông báo lỗi từ server và hiển thị
        final message = response.body;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message), // Hiển thị: "Bài thi đã có học sinh làm bài, không thể xóa."
            backgroundColor: Colors.orange.shade800, // Dùng màu cảnh báo
          ),
        );
      } else {
        // Xử lý các lỗi khác từ server
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Lỗi không xác định: ${response.statusCode}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Đã xảy ra lỗi khi kết nối: ${e.toString()}")),
        );
      }
    }
  }

  void _editExam(Map<String, dynamic> exam) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateExamScreen(editExam: exam, onSave: _loadExams),
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
        title: Text("Xin chào, $username", style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Image.asset("assets/images/vn_flag.png", width: 28, height: 25, fit: BoxFit.contain),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black87),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen()));
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              // SỬA LẠI TOÀN BỘ PHẦN NÀY
              onTap: () async {
                // Chờ kết quả trả về từ ProfileScreen
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );

                // Kiểm tra kết quả
                if (result == 'LOGGED_OUT' && mounted) {
                  // Nếu đã đăng xuất, điều hướng về trang Login và xóa hết các trang cũ
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
                  username.isNotEmpty ? username.split(' ').last.characters.first.toUpperCase() : 'GV',
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
        onRefresh: _loadExams,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreateExamScreen(onSave: _loadExams),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text("Tạo bài thi"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff0052CC),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_exams.isEmpty && !_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text("Bạn chưa tạo bài thi nào.", style: TextStyle(fontSize: 16, color: Colors.grey)),
                ),
              )
            else
              ..._exams.map(
                    (exam) => ExamCard(
                  exam: exam,
                  onDelete: () => _deleteExam(exam['id']),
                  onEdit: () => _editExam(exam),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ExamCard extends StatelessWidget {
  final Map<String, dynamic> exam;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const ExamCard({
    required this.exam,
    required this.onDelete,
    required this.onEdit,
    super.key,
  });

  String _formatDateTime(String? dateTimeString) {
    if (dateTimeString == null || dateTimeString.isEmpty) return 'N/A';
    try {
      final dateTime = DateTime.parse(dateTimeString).toLocal();
      return DateFormat('dd/MM/yyyy - HH:mm').format(dateTime);
    } catch (_) {
      return dateTimeString;
    }
  }

  void _shareCode(BuildContext context, String code) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Center(
            child: Text('Chia sẻ mã bài thi', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Sử dụng mã này để thêm bài thi:',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  code,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã sao chép mã bài thi vào bộ nhớ tạm')),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Sao chép mã'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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
            const SizedBox(height: 10),
            Text("Ngày tạo: ${_formatDateTime(exam['createdAt'])}"),
            Text("Số câu hỏi: ${exam['questionCount'] ?? 0}"),
            Text("Thời gian: ${exam['duration']} phút"),
            Text("Mã bài thi: ${exam['code'] ?? 'N/A'}", style: const TextStyle(fontWeight: FontWeight.w500)),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.analytics_outlined, color: Colors.deepPurple),
                  tooltip: "Xem kết quả",
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ExamResultsScreen(
                          examId: exam['id'] as int,
                          examTitle: exam['title'] as String? ?? 'Không có tiêu đề',
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.green),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        final code = exam['code'] ?? 'Không có mã';
                        return AlertDialog(
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text(
                                'Mã bài thi',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 25),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                code,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: code)); // ✅ Copy mã vào clipboard
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Đã sao chép mã bài thi')),
                                  );
                                },
                                icon: const Icon(Icons.copy),
                                label: const Text('Sao chép'),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Đóng'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.orange),
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'settings_profile/thong_bao.dart';
import 'thong_tin_ca_nhan.dart';
import 'them_cau_hoi.dart';
import 'trang_giao_vien.dart';
import 'dart:math';
import '../services/api_service.dart';
import '../utils/user_prefs.dart';
import 'dart:convert'; // Thêm import này để dùng jsonDecode
import 'package:http/http.dart' as http;

class CreateExamScreen extends StatefulWidget {
  final Map<String, dynamic>? editExam;
  final VoidCallback? onSave;

  const CreateExamScreen({super.key, this.editExam, this.onSave});

  @override
  State<CreateExamScreen> createState() => _CreateExamScreenState();
}

class _CreateExamScreenState extends State<CreateExamScreen> {
  Map<String, dynamic>? originalExam; // Biến để lưu dữ liệu gốc khi sửa
  bool _obscurePassword = true;
  final _formKey = GlobalKey<FormState>();
  int? userId;
  String? username;
  bool _isLoading = true;

  // Các TextEditingController giữ nguyên
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _examNameController = TextEditingController();
  String? _selectedSubject;
  String? _selectedClass;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _attemptsController = TextEditingController();
  bool _showScoreImmediately = false;

  final List<String> _subjects = ['Toán', 'Ngữ văn', 'Tiếng Anh', 'Sinh học', 'Vật lý', 'Âm nhạc', 'Mỹ thuật', 'Hóa học', 'Khác'];
  final List<String> _classes = ['Lớp 1', 'Lớp 2', 'Lớp 3', 'Lớp 4', 'Lớp 5', 'Lớp 6', 'Lớp 7', 'Lớp 8', 'Lớp 9', 'Lớp 10', 'Lớp 11', 'Lớp 12', 'Đại học'];

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await _loadUserInfo();
    if (widget.editExam != null) {
      await _fetchExamDetail(widget.editExam!['id']);
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserInfo() async {
    final user = await UserPrefs.getUserDataWithId();
    if (mounted && user != null) {
      setState(() {
        userId = user['id'];
        username = user['fullName'];
      });
    }
  }

  Future<void> _fetchExamDetail(int examId) async {
    try {
      final data = await ApiService.getExamDetails(examId);
      if (mounted) {
        setState(() {
          originalExam = data;

          _examNameController.text = data['title'] ?? '';
          _selectedSubject = data['subject'];
          _selectedClass = data['grade'];
          _selectedDate = data['deadline'] != null ? DateTime.tryParse(data['deadline']) : null;

          if (data['startTime'] != null) {
            final timeParts = data['startTime'].split(':');
            if (timeParts.length >= 2) {
              _selectedTime = TimeOfDay(
                hour: int.parse(timeParts[0]),
                minute: int.parse(timeParts[1]),
              );
            }
          }
          _durationController.text = data['duration']?.toString() ?? '';
          _attemptsController.text = data['attempts']?.toString() ?? '';
          _passwordController.text = data['password'] ?? '';
          _showScoreImmediately = data['showScore'] == true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi tải chi tiết bài thi: $e")));
      }
    }
  }

  Future<String> _generateUniqueExamCode() async {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    String code;
    do {
      code = List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
    } while (await ApiService.examCodeExists(code));
    return code;
  }

  void _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSubject == null || _selectedClass == null || _selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng điền đầy đủ thông tin")));
      return;
    }

    // XÓA BỎ KHỐI VALIDATION Ở ĐÂY VÌ ĐÃ CHUYỂN VỀ BACKEND

    final name = _examNameController.text.trim();
    final subject = _selectedSubject!;
    final deadlineDate = _selectedDate!;
    final deadline = DateTime(
      deadlineDate.year,
      deadlineDate.month,
      deadlineDate.day,
      23, 59, 59,
    ).toIso8601String();

    final startTime = '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';
    final duration = int.tryParse(_durationController.text) ?? 0;
    final attempts = int.tryParse(_attemptsController.text) ?? 1;
    final showScore = _showScoreImmediately;
    final password = _passwordController.text.trim();
    final grade = _selectedClass ?? '';

    try {
      if (widget.editExam != null) {
        // --- XỬ LÝ CẬP NHẬT ---
        // Phần này giữ nguyên vì không có logic StartTime/CreatedAt
        if (originalExam != null) {
          final originalDeadline = DateTime.tryParse(originalExam!['deadline'] ?? '');
          final originalStartParts = (originalExam!['startTime'] ?? '').split(':');
          final originalStartTime = originalStartParts.length == 2
              ? TimeOfDay(hour: int.parse(originalStartParts[0]), minute: int.parse(originalStartParts[1]))
              : null;

          final hasChanges = name != (originalExam!['title'] ?? '') ||
              subject != (originalExam!['subject'] ?? '') ||
              grade != (originalExam!['grade'] ?? '') ||
              _selectedDate != originalDeadline ||
              _selectedTime != originalStartTime ||
              duration != (originalExam!['duration'] ?? 0) ||
              attempts != (originalExam!['attempts'] ?? 1) ||
              showScore != (originalExam!['showScore'] == true) ||
              password != (originalExam!['password'] ?? '');

          if (!hasChanges) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Dữ liệu chưa được thay đổi")));
            return;
          }
        }

        // Dữ liệu cho việc cập nhật giữ nguyên, không cần thay đổi
        final updateData = {
          'title': name, 'subject': subject, 'deadline': deadline, 'startTime': startTime,
          'duration': duration, 'attempts': attempts, 'showScore': showScore, 'grade': grade, 'password': password,
        };

        await ApiService.updateExamById(widget.editExam!['id'], updateData);
        widget.onSave?.call();
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(
            builder: (_) => const TeacherScreen(),
            settings: const RouteSettings(arguments: "Cập nhật bài thi thành công"),
          ));
        }

      } else {
        // --- XỬ LÝ TẠO MỚI ---
        final examCode = await _generateUniqueExamCode();
        final examData = {
          'title': name, 'subject': subject, 'deadline': deadline, 'startTime': startTime,
          'duration': duration, 'attempts': attempts, 'showScore': showScore,
          'grade': grade, 'code': examCode, 'password': password,
        };

        // Gọi hàm createExam đã được sửa đổi
        final http.Response response = await ApiService.createExam(examData);

        if (!mounted) return;

        // Xử lý phản hồi từ server
        if (response.statusCode == 200) {
          final examId = jsonDecode(response.body)['id'];
          widget.onSave?.call();
          Navigator.push(context, MaterialPageRoute(
            builder: (context) => AddQuestionScreen(examName: name, examId: examId),
          ));
        } else {
          // Hiển thị lỗi từ server (ví dụ: "Thời gian bắt đầu không thể ở trong quá khứ.")
          final errorData = jsonDecode(response.body);
          final errorMessage = errorData['message'] ?? 'Lỗi không xác định từ server.';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Đã xảy ra lỗi kết nối: ${e.toString()}")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black87),
              onPressed: () async {
                final message = widget.editExam != null
                    ? "Bạn có chắc muốn hủy chỉnh sửa không?" : "Bạn có chắc muốn hủy tạo bài thi không?";
                final shouldExit = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Xác nhận"), content: Text(message),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Không")),
                      ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Có")),
                    ],
                  ),
                );
                if (shouldExit == true) {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const TeacherScreen()));
                }
              },
            ),
            const SizedBox(width: 4),
            Text(widget.editExam != null ? 'Chỉnh sửa bài thi' : 'Tạo bài thi',
              style: const TextStyle(color: Color(0xff003366), fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel('Tên bài thi'),
              _buildTextField(_examNameController, 'Nhập tên bài thi'),
              _buildLabel('Môn học'),
              _buildDropdown(_subjects, _selectedSubject, (val) => setState(() => _selectedSubject = val)),
              _buildLabel('Lớp'),
              _buildDropdown(_classes, _selectedClass, (val) => setState(() => _selectedClass = val)),
              _buildLabel('Hạn nộp'),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context, initialDate: _selectedDate ?? DateTime.now(),
                    firstDate: DateTime.now(), lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
                child: _buildDateTimeBox(_selectedDate != null ? DateFormat('dd/MM/yyyy').format(_selectedDate!) : 'Chọn ngày'),
              ),
              _buildLabel('Giờ bắt đầu'),
              InkWell(
                onTap: () async {
                  final picked = await showTimePicker(context: context, initialTime: _selectedTime ?? TimeOfDay.now());
                  if (picked != null) setState(() => _selectedTime = picked);
                },
                child: _buildDateTimeBox(_selectedTime != null ? _selectedTime!.format(context) : 'Chọn giờ'),
              ),
              _buildLabel('Thời lượng (phút)'),
              _buildTextField(_durationController, 'VD: 45', isNumber: true),
              _buildLabel('Số lần làm lại'),
              _buildTextField(_attemptsController, 'VD: 2', isNumber: true),
              _buildLabel('Mật khẩu bài thi'),
              _buildPasswordField(_passwordController, 'Nhập mật khẩu (nếu có)'),
              CheckboxListTile(
                value: _showScoreImmediately,
                onChanged: (val) => setState(() => _showScoreImmediately = val ?? false),
                title: const Text("Hiển thị điểm ngay sau khi nộp"),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 24),
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff0052cc), foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(widget.editExam != null ? 'Cập nhật bài thi' : 'Tạo bài thi', style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                  if (widget.editExam != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit_note),
                        label: const Text("Sửa câu hỏi trong bài thi"),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          foregroundColor: Colors.blue, side: const BorderSide(color: Colors.blue),
                        ),
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => AddQuestionScreen(
                              examId: widget.editExam!['id'],
                              examName: _examNameController.text,
                              isEditing: true,
                            ),
                          ));
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField(TextEditingController controller, String hint) {
    return TextFormField(
      controller: controller,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        hintText: hint,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
      ),
      validator: (value) {
        if (value != null && value.isNotEmpty && value.length < 4) {
          return 'Mật khẩu phải từ 4 ký tự trở lên';
        }
        return null;
      },
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.grey[100],
      ),
      validator: (val) =>
      val == null || val.isEmpty
          ? 'Không được để trống'
          : null,
    );
  }

  Widget _buildDropdown(List<String> items, String? value, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.grey[100],
      ),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
      validator: (val) => val == null ? 'Hãy chọn một mục' : null,
    );
  }

  Widget _buildDateTimeBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade400),
        color: Colors.grey[100],
      ),
      child: Text(text),
    );
  }
}

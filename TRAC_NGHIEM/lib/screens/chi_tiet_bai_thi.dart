import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../utils/user_prefs.dart';
import 'lam_bai_thi.dart';
import 'xem_lai_bai_thi.dart';

class ExamDetailScreen extends StatefulWidget {
  final Map<String, dynamic> exam;

  const ExamDetailScreen({
    required this.exam,
    super.key,
  });

  @override
  State<ExamDetailScreen> createState() => _ExamDetailScreenState();
}

class _ExamDetailScreenState extends State<ExamDetailScreen> {
  List<Map<String, dynamic>> attemptHistory = [];
  bool isLoading = true;
  String username = '';
  int? userId;

  int get userAttempts => attemptHistory.length;
  int get maxAttempts => widget.exam['attempts'] as int? ?? 1;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final user = await UserPrefs.getUserDataWithId();
      if (user != null) {
        userId = user['id'];
        username = user['fullName'] ?? '';
      }
      final history = await ApiService.getAttemptHistory(widget.exam['id'] as int);
      if (mounted) {
        setState(() {
          attemptHistory = history;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải dữ liệu chi tiết: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _startQuiz() async {
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể xác định người dùng. Vui lòng thử lại.')),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          examId: widget.exam['id'] as int,
          examTitle: widget.exam['title'] as String? ?? 'Không có tiêu đề',
          duration: widget.exam['duration'] as int? ?? 0,
          onSubmit: _loadData,
        ),
      ),
    );
  }

  String _formatDateTime(String? dtStr) {
    if (dtStr == null || dtStr.isEmpty) return 'Không có';
    try {
      final dt = DateTime.parse(dtStr).toLocal();
      return DateFormat('dd/MM/yyyy - HH:mm').format(dt);
    } catch (_) {
      return dtStr;
    }
  }

  DateTime? _getFullStartTime(Map<String, dynamic> exam) {
    final createdAtString = exam['createdAt'] as String?;
    final startTimeString = exam['startTime'] as String?;

    if (createdAtString == null || startTimeString == null) {
      return null;
    }

    try {
      final createdDate = DateTime.parse(createdAtString);
      final timeParts = startTimeString.split(':');
      if (timeParts.length == 2) {
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        return DateTime(createdDate.year, createdDate.month, createdDate.day, hour, minute);
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final exam = widget.exam;

    final deadlineString = exam['deadline'] as String?;
    final deadline = deadlineString != null ? DateTime.tryParse(deadlineString)?.toLocal() : null;
    final fullStartTime = _getFullStartTime(exam);
    final now = DateTime.now();

    final bool isExpired = deadline != null ? now.isAfter(deadline) : false;
    final bool hasStarted = fullStartTime != null ? now.isAfter(fullStartTime) : true;
    final bool hasAttemptsLeft = userAttempts < maxAttempts;

    final bool canAttempt = hasAttemptsLeft && !isExpired && hasStarted;
    String buttonLabel = 'Làm bài';

    if (isExpired) {
      buttonLabel = 'Đã hết hạn';
    } else if (!hasAttemptsLeft) {
      buttonLabel = 'Hết lượt làm bài';
    } else if (!hasStarted) {
      buttonLabel = 'Chưa đến giờ làm bài';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết bài thi'),
        backgroundColor: const Color(0xff0052CC),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              exam['title'] ?? 'Không có tiêu đề',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            InfoRow(icon: Icons.play_circle_outline, text: "Bắt đầu lúc: ${_formatDateTime(fullStartTime?.toIso8601String())}"),
            InfoRow(icon: Icons.calendar_today_outlined, text: "Hạn nộp: ${_formatDateTime(exam['deadline'] as String?)}"),
            InfoRow(icon: Icons.timer_outlined, text: "Thời gian làm bài: ${exam['duration']} phút"),
            InfoRow(icon: Icons.help_outline, text: "Số câu hỏi: ${exam['questionCount'] ?? 0}"),
            InfoRow(icon: Icons.repeat, text: "Số lần đã làm: $userAttempts / $maxAttempts"),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: canAttempt ? _startQuiz : null,
              icon: const Icon(Icons.play_arrow),
              label: Text(buttonLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: canAttempt ? const Color(0xff0052CC) : Colors.grey,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Lịch sử làm bài', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 16),
            if (attemptHistory.isEmpty)
              const Text('Bạn chưa làm bài này lần nào.')
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: attemptHistory.length,
                itemBuilder: (context, index) {
                  final historyItem = attemptHistory[index];
                  final bool showScore = (exam['showScore'] as bool? ?? false);
                  final score = historyItem['score'];

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: CircleAvatar(child: Text('${index + 1}')),
                      title: Text(showScore ? 'Điểm: $score' : 'Đã nộp bài'),
                      subtitle: Text('Lúc: ${_formatDateTime(historyItem['submittedAt'] as String?)}'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReviewScreen(
                              resultId: historyItem['id'] as int,
                              showScore: showScore,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const InfoRow({required this.icon, required this.text, Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 20),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}
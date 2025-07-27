import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class ExamResultsScreen extends StatefulWidget {
  final int examId;
  final String examTitle;

  const ExamResultsScreen({
    required this.examId,
    required this.examTitle,
    Key? key,
  }) : super(key: key);

  @override
  State<ExamResultsScreen> createState() => _ExamResultsScreenState();
}

class _ExamResultsScreenState extends State<ExamResultsScreen> {
  late Future<List<Map<String, dynamic>>> _resultsFuture;

  @override
  void initState() {
    super.initState();
    _loadExamResults();
  }

  void _loadExamResults() {
    setState(() {
      _resultsFuture = ApiService.getExamResultsForTeacher(widget.examId);
    });
  }

  String _formatDateTime(String? dtStr) {
    if (dtStr == null || dtStr.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(dtStr).toLocal();
      return DateFormat('dd/MM/yyyy - HH:mm').format(dt);
    } catch (_) {
      return dtStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kết quả: ${widget.examTitle}'),
        backgroundColor: const Color(0xff0052CC),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _resultsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi tải kết quả: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'Chưa có học sinh nào nộp bài.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final results = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _loadExamResults(),
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: results.length,
              itemBuilder: (context, index) {
                final result = results[index];
                final studentName = result['fullName'] ?? 'Không rõ';

                // SỬA LẠI DÒNG NÀY ĐỂ FIX LỖI
                // Lấy giá trị dưới dạng 'num' (có thể là int hoặc double)
                // sau đó chuyển đổi nó thành double.
                final score = (result['score'] as num?)?.toDouble();

                final submittedAt = result['submittedAt'] as String?;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blueGrey.shade50,
                      child: Text((index + 1).toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    title: Text(studentName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Nộp lúc: ${_formatDateTime(submittedAt)}'),
                    trailing: Chip(
                      label: Text(
                        '${score?.toStringAsFixed(1) ?? 'N/A'} điểm',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: Colors.blueAccent,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

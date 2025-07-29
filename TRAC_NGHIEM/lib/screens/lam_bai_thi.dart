import 'dart:async';
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../services/api_service.dart';
import '../utils/user_prefs.dart';

class QuizScreen extends StatefulWidget {
  final int examId;
  final String examTitle;
  final int duration;
  final VoidCallback onSubmit; // Callback để màn hình trước có thể tải lại dữ liệu

  const QuizScreen({
    required this.examId,
    required this.examTitle,
    required this.duration,
    required this.onSubmit,
    Key? key,
  }) : super(key: key);

  @override
  _QuizScreenState createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  // State cho logic timer và scroll
  late Timer _timer;
  late Duration _remaining;
  final ItemScrollController _itemScrollController = ItemScrollController();

  // State cho dữ liệu
  bool _isLoading = true;
  List<Map<String, dynamic>> _questions = [];
  String _studentName = '';
  int? _userId;

  // State lưu trữ câu trả lời của người dùng: Map<questionId, answerId>
  final Map<int, int> _selectedAnswers = {};

  @override
  void initState() {
    super.initState();
    _remaining = Duration(minutes: widget.duration);
    _loadQuizData();
  }

  /// Tải dữ liệu từ API khi màn hình khởi tạo
  Future<void> _loadQuizData() async {
    setState(() => _isLoading = true);
    try {
      // Tải song song thông tin user và danh sách câu hỏi
      final results = await Future.wait([
        UserPrefs.getUserDataWithId(),
        ApiService.getQuestionsForQuiz(widget.examId),
      ]);

      final user = results[0] as Map<String, dynamic>?;
      final questions = results[1] as List<Map<String, dynamic>>;

      if (mounted) {
        setState(() {
          _studentName = user?['fullName'] ?? '...';
          _userId = user?['id'];
          _questions = questions;
          _isLoading = false;
        });
        _startTimer(); // Bắt đầu đếm giờ sau khi tải xong
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi tải dữ liệu bài thi: ${e.toString()}")),
        );
        Navigator.of(context).pop(); // Quay về nếu không tải được
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remaining.inSeconds <= 0) {
        timer.cancel();
        _submitQuiz(isTimeUp: true); // Tự động nộp bài khi hết giờ
      } else {
        setState(() => _remaining -= const Duration(seconds: 1));
      }
    });
  }

  /// Gửi bài làm lên server
  Future<void> _submitQuiz({bool isTimeUp = false}) async {
    if (_timer.isActive) _timer.cancel();
    if (_userId == null) return;

    // Hiển thị dialog loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Chuẩn bị payload (dữ liệu gửi đi)
      final List<Map<String, int>> answersPayload = _selectedAnswers.entries
          .map((entry) => {"questionId": entry.key, "answerId": entry.value})
          .toList();

      final response = await ApiService.submitQuiz(widget.examId, answersPayload);

      Navigator.of(context).pop(); // Tắt dialog loading

      if (response.statusCode == 200) {
        widget.onSubmit(); // Gọi callback để màn hình trước (ExamDetail) tải lại
        if (mounted) {
          // Hiển thị dialog thông báo nộp bài thành công
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(isTimeUp ? "Đã hết giờ!" : "Nộp bài thành công!"),
              content: Text(isTimeUp
                  ? "Bài làm của bạn đã được tự động nộp."
                  : "Bạn đã hoàn thành bài thi."),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("OK"),
                )
              ],
            ),
          );
          if (mounted) Navigator.of(context).pop(); // Quay về màn hình chi tiết
        }
      } else {
        throw Exception("Lỗi từ server: ${response.body}");
      }
    } catch (e) {
      Navigator.of(context).pop(); // Tắt dialog loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi khi nộp bài: ${e.toString()}")),
        );
      }
    }
  }

  // --- Các hàm và widget UI khác ---

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _scrollToQuestion(int index) {
    _itemScrollController.scrollTo(
      index: index,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _showConfirmationDialog() async {
    return showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
              title: const Text('Xác nhận nộp bài'),
              content: const Text('Bạn có chắc chắn muốn nộp bài không?'),
              actions: <Widget>[
                TextButton(
                    child: const Text('Hủy'),
                    onPressed: () => Navigator.of(context).pop()),
                FilledButton(
                    child: const Text('Xác nhận'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _submitQuiz();
                    })
              ]);
        });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
          appBar: AppBar(title: Text(widget.examTitle)),
          body: const Center(child: CircularProgressIndicator()));
    }

    return WillPopScope(
      onWillPop: () async {
        await _showConfirmationDialog();
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('Làm bài thi'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 1,
          automaticallyImplyLeading: false,
        ),
        body: Column(
          children: [
            _buildTopBar(),
            _buildExamInfo(),
            Expanded(child: _buildQuestionsList()),
          ],
        ),
      ),
    );
  }

  // Các widget để build UI, logic không thay đổi nhiều
  Widget _buildTopBar() {
    final bool timeRunningOut = _remaining.inSeconds <= 60 && _remaining.inSeconds > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Chip(
                avatar: Icon(
                  Icons.timer_outlined,
                  color: timeRunningOut ? Colors.white : Colors.blueAccent,
                ),
                label: Text(
                  _formatDuration(_remaining),
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: timeRunningOut ? Colors.white : Colors.blueAccent),
                ),
                backgroundColor: timeRunningOut ? Colors.redAccent.withOpacity(0.9) : Colors.blue.shade50,
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.send, size: 20),
                label: const Text("Nộp bài"),
                onPressed: _showConfirmationDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildQuestionNavigator(),
        ],
      ),
    );
  }

  Widget _buildQuestionNavigator() {
    return SizedBox(
      height: 42,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _questions.length,
        itemBuilder: (context, index) {
          final questionId = _questions[index]['id'] as int;
          final isAnswered = _selectedAnswers.containsKey(questionId);
          return GestureDetector(
            onTap: () => _scrollToQuestion(index),
            child: Container(
              width: 42,
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              decoration: BoxDecoration(
                color: isAnswered ? Colors.green.shade100 : Colors.transparent,
                border: Border.all(color: isAnswered ? Colors.green : Colors.grey.shade400),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text('${index + 1}',
                    style: TextStyle(
                        color: isAnswered ? Colors.green.shade900 : Colors.black54,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExamInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      color: const Color(0xFFE3F2FD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.examTitle,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Học sinh: $_studentName'),
              Text('Tổng số câu: ${_questions.length}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsList() {
    return ScrollablePositionedList.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _questions.length,
        itemScrollController: _itemScrollController,
        itemBuilder: (context, index) {
          final question = _questions[index];
          return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Câu ${index + 1}: ${question['questionText']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 16),
                        ..._buildAnswerOptions(question),
                      ])));
        });
  }

  List<Widget> _buildAnswerOptions(Map<String, dynamic> question) {
    final questionId = question['id'] as int;
    final answers = question['answers'] as List<dynamic>;

    return answers.map((answer) {
      final answerId = answer['id'] as int;
      final isSelected = _selectedAnswers[questionId] == answerId;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedAnswers[questionId] = answerId;
            });
          },
          child: Ink(
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue.shade50 : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isSelected ? Colors.blueAccent : Colors.grey.shade300, width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon( isSelected ? Icons.check_circle : Icons.radio_button_unchecked, color: isSelected ? Colors.blueAccent : Colors.grey.shade500),
                  const SizedBox(width: 12),
                  Expanded(child: Text(answer['answerText'] as String, style: const TextStyle(fontSize: 16))),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
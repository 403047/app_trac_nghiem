import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'settings_profile/thong_bao.dart';
import 'thong_tin_ca_nhan.dart';
import 'trang_giao_vien.dart';
import 'dart:convert';

class QuestionModel {
  final int id;
  final String question;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final String correctAnswer;

  QuestionModel({
    required this.id,
    required this.question,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.correctAnswer,
  });
}

class AddQuestionScreen extends StatefulWidget {
  final int examId;
  final String examName;
  final bool isEditing;

  const AddQuestionScreen({
    super.key,
    required this.examId,
    required this.examName,
    this.isEditing = false,
  });

  @override
  State<AddQuestionScreen> createState() => _AddQuestionScreenState();
}

class _AddQuestionScreenState extends State<AddQuestionScreen> {
  Map<String, dynamic>? _originalQuestionData;
  final _singleFormKey = GlobalKey<FormState>();
  final _bulkFormKey = GlobalKey<FormState>();

  final _questionController = TextEditingController();
  final _optionAController = TextEditingController();
  final _optionBController = TextEditingController();
  final _optionCController = TextEditingController();
  final _optionDController = TextEditingController();
  final _bulkPasteController = TextEditingController();
  String? _correctAnswer = 'A';
  List<QuestionModel> _questions = [];
  int? _editingQuestionId;
  bool _isLoading = true;

  final bool isLoggedIn = true;

  @override
  void initState() {
    super.initState();
    _loadQuestionsFromApi();
  }

  Future<void> _loadQuestionsFromApi() async {
    setState(() => _isLoading = true);
    try {
      final questionsData = await ApiService.getQuestionsByExamId(widget.examId);
      List<QuestionModel> loadedQuestions = [];

      for (var qData in questionsData) {
        final List answers = qData['answers'] ?? [];
        final answerMap = {for (var a in answers) a['answerLabel']: a['answerText']};
        final correct = answers.firstWhere((a) => a['isCorrect'] == true, orElse: () => {})['answerLabel'];

        loadedQuestions.add(
          QuestionModel(
            id: qData['id'],
            question: qData['questionText'],
            optionA: answerMap['A'] ?? '',
            optionB: answerMap['B'] ?? '',
            optionC: answerMap['C'] ?? '',
            optionD: answerMap['D'] ?? '',
            correctAnswer: correct ?? 'A',
          ),
        );
      }
      if (mounted) {
        setState(() {
          _questions = loadedQuestions;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi tải câu hỏi: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _editQuestion(QuestionModel question) {
    setState(() {
      _editingQuestionId = question.id;
      _questionController.text = question.question;
      _optionAController.text = question.optionA;
      _optionBController.text = question.optionB;
      _optionCController.text = question.optionC;
      _optionDController.text = question.optionD;
      _correctAnswer = question.correctAnswer;

      _originalQuestionData = {
        'questionText': question.question,
        'answers': {
          'A': question.optionA,
          'B': question.optionB,
          'C': question.optionC,
          'D': question.optionD,
        },
        'correctAnswer': question.correctAnswer,
      };
    });
  }

  void _addOrUpdateQuestion() async {
    final questionText = _questionController.text.trim();
    final answers = {
      'A': _optionAController.text.trim(),
      'B': _optionBController.text.trim(),
      'C': _optionCController.text.trim(),
      'D': _optionDController.text.trim(),
    };
    final correctAnswer = _correctAnswer ?? 'A';

    try {
      if (_editingQuestionId != null) {
        await ApiService.updateQuestion(
          questionId: _editingQuestionId!,
          examId: widget.examId,
          questionText: questionText,
          answers: answers,
          correctAnswer: correctAnswer,
        );
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật câu hỏi')));
      } else {
        await ApiService.insertQuestionWithAnswers(
          examId: widget.examId,
          questionText: questionText,
          answers: answers,
          correctAnswer: correctAnswer,
        );
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã thêm câu hỏi thành công')));
      }

      _resetForm();
      await _loadQuestionsFromApi();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi lưu câu hỏi: $e')));
      }
    }
  }

  void _resetForm() {
    setState(() {
      _editingQuestionId = null;
      _originalQuestionData = null;
      _singleFormKey.currentState?.reset();
      _questionController.clear();
      _optionAController.clear();
      _optionBController.clear();
      _optionCController.clear();
      _optionDController.clear();
      _correctAnswer = 'A';
    });
  }

  void _confirmDeleteQuestion(QuestionModel question) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Xác nhận xoá"),
        content: const Text("Bạn có chắc muốn xoá câu hỏi này không?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Huỷ")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Xoá", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiService.deleteQuestion(question.id);
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã xoá câu hỏi")));
          _loadQuestionsFromApi();
        }
      } catch (e) {
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi khi xoá: $e")));
        }
      }
    }
  }

  void _parseAndAddStructuredQuestions() async {
    final text = _bulkPasteController.text.trim();
    final lines = text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    List<Map<String, dynamic>> newQuestionsData = [];
    Map<String, dynamic> currentQuestion = {};

    for (String line in lines) {
      if (RegExp(r'^\d+\.').hasMatch(line)) {
        if (currentQuestion.isNotEmpty) {
          newQuestionsData.add(currentQuestion);
        }
        currentQuestion = {'questionText': line.replaceFirst(RegExp(r'^\d+\.\s*'), '')};
      } else if (RegExp(r'^[A-D]\.').hasMatch(line)) {
        currentQuestion[line.substring(0, 1)] = line.substring(2).trim();
      } else if (line.toLowerCase().startsWith('answer:')) {
        currentQuestion['correctAnswer'] = line.split(':').last.trim().toUpperCase();
      }
    }
    if (currentQuestion.isNotEmpty) {
      newQuestionsData.add(currentQuestion);
    }

    int successCount = 0;
    for (var qData in newQuestionsData) {
      try {
        await ApiService.insertQuestionWithAnswers(
          examId: widget.examId,
          questionText: qData['questionText'],
          answers: {
            'A': qData['A'], 'B': qData['B'],
            'C': qData['C'], 'D': qData['D'],
          },
          correctAnswer: qData['correctAnswer'],
        );
        successCount++;
      } catch (e) {
        print("Lỗi thêm câu hỏi từ bulk: $e");
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Đã thêm thành công $successCount câu hỏi.")));
      _bulkPasteController.clear();
      _loadQuestionsFromApi();
    }
  }

  Future<void> _finishExam() async {
    try {
      final List<Map<String, dynamic>> questions = await ApiService.getQuestionsByExamId(widget.examId);

      if (!mounted) return;

      if (questions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bạn phải thêm ít nhất 1 câu hỏi trước khi hoàn tất!')),
        );
        return;
      }

      const message = 'Bài thi đã được lưu thành công!';
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const TeacherScreen(),
          settings: const RouteSettings(arguments: message),
        ),
            (route) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã xảy ra lỗi: $e')),
        );
      }
    }
  }

  Widget _buildAnswerField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Đáp án $label", style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: (value) => value!.isEmpty ? 'Không được để trống' : null,
          decoration: InputDecoration(
            hintText: "Nhập đáp án $label...",
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildRadioOption(String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Radio<String>(
          value: value,
          groupValue: _correctAnswer,
          onChanged: (val) => setState(() => _correctAnswer = val),
        ),
        Text("Đáp án $value"),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.examName, style: const TextStyle(color: Color(0xff003366), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,

      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            Form(
              key: _singleFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Nội dung câu hỏi", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _questionController,
                    validator: (value) => value!.isEmpty ? 'Không được để trống' : null,
                    maxLines: 2,
                    decoration: const InputDecoration(hintText: "Nhập câu hỏi...", border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  _buildAnswerField("A", _optionAController),
                  _buildAnswerField("B", _optionBController),
                  _buildAnswerField("C", _optionCController),
                  _buildAnswerField("D", _optionDController),
                  const SizedBox(height: 16),
                  const Text("Chọn đáp án đúng", style: TextStyle(fontWeight: FontWeight.bold)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildRadioOption("A"),
                      _buildRadioOption("B"),
                      _buildRadioOption("C"),
                      _buildRadioOption("D"),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_singleFormKey.currentState!.validate()) {
                          _addOrUpdateQuestion();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff0052cc), foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_editingQuestionId != null ? Icons.save : Icons.add, size: 20),
                          const SizedBox(width: 8),
                          Text(_editingQuestionId != null ? "Lưu câu hỏi" : "Thêm câu mới"),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 40, thickness: 1),
            Form(
              key: _bulkFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.content_paste, color: Colors.teal),
                      SizedBox(width: 8),
                      Text("Hoặc dán nhiều câu hỏi từ Excel", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _bulkPasteController,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      hintText: "1. Câu hỏi?\nA. Đáp án A\nB. Đáp án B\nC. Đáp án C\nD. Đáp án D\nANSWER: A",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (_bulkPasteController.text.isNotEmpty) {
                          _parseAndAddStructuredQuestions();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.playlist_add),
                      label: const Text("Thêm từ văn bản"),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 40, thickness: 1),
            Row(
              children: [
                const Icon(Icons.list_alt, color: Colors.blue),
                const SizedBox(width: 8),
                Text('Danh sách câu hỏi đã thêm (${_questions.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 10),
            // SỬA LẠI TOÀN BỘ PHẦN NÀY
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _questions.length,
              itemBuilder: (context, index) {
                final q = _questions[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                "${index + 1}. ${q.question}",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                            IconButton(icon: const Icon(Icons.edit, color: Colors.orange, size: 20), onPressed: () => _editQuestion(q), tooltip: "Sửa"),
                            IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => _confirmDeleteQuestion(q), tooltip: "Xóa"),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 16.0, top: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('A. ${q.optionA}'),
                              Text('B. ${q.optionB}'),
                              Text('C. ${q.optionC}'),
                              Text('D. ${q.optionD}'),
                              const SizedBox(height: 4),
                              Text(
                                'ANSWER: ${q.correctAnswer}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _finishExam,
                icon: const Icon(Icons.task_alt_rounded),
                label: const Text("Hoàn tất tạo bài thi", style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

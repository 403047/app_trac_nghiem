import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ReviewScreen extends StatefulWidget {
  final int resultId;
  final bool showScore;

  const ReviewScreen({
    required this.resultId,
    required this.showScore,
    Key? key,
  }) : super(key: key);

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late Future<List<dynamic>> _reviewFuture;

  @override
  void initState() {
    super.initState();
    // Gọi API để lấy dữ liệu
    _reviewFuture = ApiService.getReviewData(widget.resultId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Xem lại bài làm'),
        backgroundColor: const Color(0xff0052CC),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _reviewFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi khi tải dữ liệu: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Không có dữ liệu để xem lại.'));
          }

          final reviewList = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reviewList.length,
            separatorBuilder: (_, __) => const Divider(height: 32, thickness: 1),
            itemBuilder: (context, index) {
              return _buildQuestionTile(reviewList[index], index + 1);
            },
          );
        },
      ),
    );
  }

  Widget _buildQuestionTile(Map<String, dynamic> questionData, int questionNumber) {
    final List<dynamic> answers = questionData['answers'];
    final int? selectedAnswerId = questionData['selectedAnswerId'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Câu $questionNumber: ${questionData['questionText']}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        const SizedBox(height: 12),
        ...answers.map((option) {
          Color? backgroundColor;
          Widget? trailingIcon;
          final bool isCorrect = option['isCorrect'] as bool;
          final bool isSelected = option['id'] == selectedAnswerId;

          if (widget.showScore) {
            if (isCorrect) {
              backgroundColor = Colors.green.shade100;
              trailingIcon = const Icon(Icons.check_circle, color: Colors.green);
            } else if (isSelected) {
              backgroundColor = Colors.red.shade100;
              trailingIcon = const Icon(Icons.cancel, color: Colors.red);
            }
          }

          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300)),
            child: ListTile(
              leading: Radio<int>(
                value: option['id'] as int,
                groupValue: selectedAnswerId,
                onChanged: null, // Vô hiệu hóa
              ),
              title: Text(option['text'] as String),
              trailing: trailingIcon,
            ),
          );
        }).toList(),
      ],
    );
  }
}
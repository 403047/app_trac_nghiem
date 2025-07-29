import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../utils/user_prefs.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  late Future<List<Map<String, dynamic>>> _notificationsFuture;
  String username = "";

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  void _loadInitialData() {
    _notificationsFuture = ApiService.getNotifications();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    final user = await UserPrefs.getUserDataWithId();
    if (mounted && user != null) {
      setState(() {
        username = user['fullName'] ?? '';
      });
    }
  }

  String _formatDateTime(String? dtStr) {
    if (dtStr == null || dtStr.isEmpty) return 'Không có';
    try {
      final dt = DateTime.parse(dtStr).toLocal();
      return DateFormat('HH:mm - dd/MM/yyyy').format(dt);
    } catch (_) {
      return dtStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF4F6FA),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Thông báo", style: TextStyle(color: Colors.black87)),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Image.asset("assets/images/vn_flag.png", width: 28),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Icon(Icons.notifications, color: Colors.black54), // Thay đổi icon
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              backgroundColor: Colors.grey[300],
              child: Text(
                  username.isNotEmpty ? username.split(' ').last.characters.first.toUpperCase() : '',
                  style: const TextStyle(color: Colors.black)
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _notificationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi tải thông báo: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          }

          final notifications = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE3F2FD),
                    child: Icon(Icons.timer_outlined, color: Colors.blueAccent),
                  ),
                  title: Text(
                    'Bài thi "${notification['title']}" sắp hết hạn!',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Hạn nộp: ${_formatDateTime(notification['deadline'])}'),
                  onTap: () {
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset("assets/images/empty_bell.png", width: 50, height: 50),
              const SizedBox(height: 16),
              const Text(
                "Chưa có thông báo nào.",
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
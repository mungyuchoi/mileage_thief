import 'package:flutter/material.dart';
import 'cancellation_notification_register_screen.dart';

class CancellationNotificationScreen extends StatefulWidget {
  const CancellationNotificationScreen({super.key});

  @override
  State<CancellationNotificationScreen> createState() => _CancellationNotificationScreenState();
}

class _CancellationNotificationScreenState extends State<CancellationNotificationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('취소표 알림'),
        backgroundColor: const Color(0xFF00256B),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: '내 알림'),
            Tab(text: '인기구간'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyNotificationsTab(),
          _buildPopularRoutesTab(),
        ],
      ),
      floatingActionButton: _currentTabIndex == 0 ? FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CancellationNotificationRegisterScreen(),
            ),
          );
        },
        backgroundColor: const Color(0xFF00256B),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ) : null,
    );
  }

  Widget _buildMyNotificationsTab() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 80,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            '설정된 알림이 없습니다',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '취소표 알림을 설정하여\n원하는 항공편의 취소표 소식을 받아보세요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularRoutesTab() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.trending_up,
            size: 80,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            '인기구간 정보가 없습니다',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '많은 사람들이 관심있어 하는\n항공편 취소표 정보를 확인해보세요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
} 
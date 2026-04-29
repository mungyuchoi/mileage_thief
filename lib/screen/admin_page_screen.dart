import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/user_service.dart';
import 'ad_manage_screen.dart';
import 'contest_manage_screen.dart';

class AdminPageScreen extends StatefulWidget {
  const AdminPageScreen({super.key});

  @override
  State<AdminPageScreen> createState() => _AdminPageScreenState();
}

class _AdminPageScreenState extends State<AdminPageScreen> {
  bool _isLoading = true;
  bool _canAccessAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadAdminAccess();
  }

  Future<void> _loadAdminAccess() async {
    final user = AuthService.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _canAccessAdmin = false;
      });
      return;
    }

    final userData = await UserService.getUserFromFirestore(user.uid);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _canAccessAdmin = _hasAdminAccess(userData?['roles']);
    });
  }

  bool _hasAdminAccess(dynamic roles) {
    if (roles is List) {
      return roles.any((role) {
        final value = role.toString().trim();
        return value == 'admin' || value == 'owner';
      });
    }
    if (roles is Map) {
      return roles['admin'] == true || roles['owner'] == true;
    }
    if (roles is String) {
      final value = roles.trim();
      return value == 'admin' || value == 'owner';
    }
    return false;
  }

  Future<void> _open(Widget page) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        title: const Text(
          '관리자 페이지',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_canAccessAdmin
              ? const Center(
                  child: Text(
                    '관리자 권한이 없습니다.',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    _AdminMenuTile(
                      title: '광고 관리',
                      description: '앱 진입 BottomSheet 광고를 설정합니다.',
                      icon: Icons.campaign_outlined,
                      onTap: () => _open(const AdManageScreen()),
                    ),
                    _AdminMenuTile(
                      title: '콘테스트 관리',
                      description: '콘테스트를 생성하고 관리합니다.',
                      icon: Icons.emoji_events_outlined,
                      onTap: () => _open(const ContestManageScreen()),
                    ),
                  ],
                ),
    );
  }
}

class _AdminMenuTile extends StatelessWidget {
  const _AdminMenuTile({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(icon, color: const Color(0xFF74512D)),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(description),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

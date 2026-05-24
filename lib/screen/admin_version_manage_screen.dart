import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/admin_version_service.dart';

class AdminVersionManageScreen extends StatefulWidget {
  const AdminVersionManageScreen({super.key});

  @override
  State<AdminVersionManageScreen> createState() =>
      _AdminVersionManageScreenState();
}

class _AdminVersionManageScreenState extends State<AdminVersionManageScreen> {
  static const Color _accent = Color(0xFF74512D);
  static const Color _background = Color(0xFFF7F7FA);
  static final RegExp _versionPattern = RegExp(r'^\d+(\.\d+){1,3}$');

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _androidController = TextEditingController();
  final TextEditingController _iosController = TextEditingController();
  final TextEditingController _latestController = TextEditingController();

  String _currentVersion = '';
  String _currentBuildNumber = '';
  bool _isLoading = true;
  bool _isSaving = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  @override
  void dispose() {
    _androidController.dispose();
    _iosController.dispose();
    _latestController.dispose();
    super.dispose();
  }

  Future<void> _loadVersion() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait<Object>([
        AdminVersionService.loadVersion(),
        PackageInfo.fromPlatform(),
      ]);
      final versionInfo = results[0] as AdminVersionInfo;
      final packageInfo = results[1] as PackageInfo;

      if (!mounted) return;
      _androidController.text = versionInfo.androidLatest;
      _iosController.text = versionInfo.iosLatest;
      _latestController.text = versionInfo.latest;
      setState(() {
        _currentVersion = packageInfo.version;
        _currentBuildNumber = packageInfo.buildNumber;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveVersion() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    setState(() => _isSaving = true);
    try {
      await AdminVersionService.saveVersion(
        AdminVersionInfo(
          androidLatest: _androidController.text.trim(),
          iosLatest: _iosController.text.trim(),
          latest: _latestController.text.trim(),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('버전 정보를 업로드했습니다.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('업로드 실패: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _applyCurrentVersionToPlatform() {
    if (_currentVersion.isEmpty) return;

    if (Platform.isAndroid) {
      _androidController.text = _currentVersion;
      _showAppliedToast('Android');
    } else if (Platform.isIOS) {
      _iosController.text = _currentVersion;
      _showAppliedToast('iPhone');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Android 또는 iPhone 앱에서 사용할 수 있습니다.')),
      );
    }
  }

  void _applyCurrentVersionToAll() {
    if (_currentVersion.isEmpty) return;
    _androidController.text = _currentVersion;
    _iosController.text = _currentVersion;
    _latestController.text = _currentVersion;
    _showAppliedToast('전체');
  }

  void _applyCurrentVersionToLatest() {
    if (_currentVersion.isEmpty) return;
    _latestController.text = _currentVersion;
    _showAppliedToast('공통 latest');
  }

  void _showAppliedToast(String target) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$target 버전을 $_currentVersion(으)로 맞췄습니다.')),
    );
  }

  String get _platformLabel {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iPhone';
    return Platform.operatingSystem;
  }

  String get _currentVersionLabel {
    if (_currentVersion.isEmpty) return '확인 중';
    if (_currentBuildNumber.isEmpty) return _currentVersion;
    return '$_currentVersion+$_currentBuildNumber';
  }

  String? _requiredVersionValidator(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return '버전을 입력해주세요.';
    if (!_versionPattern.hasMatch(trimmed)) {
      return '예: 2.2.55 형식으로 입력해주세요.';
    }
    return null;
  }

  String? _optionalVersionValidator(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    if (!_versionPattern.hasMatch(trimmed)) {
      return '예: 2.2.55 형식으로 입력해주세요.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text('버전 관리'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: '새로고침',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _isLoading || _isSaving ? null : _loadVersion,
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _isLoading || _error != null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _isSaving ? null : _saveVersion,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.cloud_upload_outlined),
                  label:
                      Text(_isSaving ? '업로드 중...' : 'Realtime Database에 업로드'),
                ),
              ),
            ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_accent),
        ),
      );
    }

    final error = _error;
    if (error != null) {
      return _VersionErrorState(
        error: error,
        onRetry: _loadVersion,
      );
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _VersionSummaryCard(
            currentVersionLabel: _currentVersionLabel,
            platformLabel: _platformLabel,
          ),
          const SizedBox(height: 14),
          _QuickApplyCard(
            currentVersion: _currentVersion,
            platformLabel: _platformLabel,
            onApplyPlatform: _applyCurrentVersionToPlatform,
            onApplyLatest: _applyCurrentVersionToLatest,
            onApplyAll: _applyCurrentVersionToAll,
          ),
          const SizedBox(height: 14),
          _buildVersionField(
            controller: _androidController,
            label: 'Android 최신 버전',
            databaseKey: 'androidLatest',
            icon: Icons.android_rounded,
            validator: _requiredVersionValidator,
          ),
          const SizedBox(height: 12),
          _buildVersionField(
            controller: _iosController,
            label: 'iPhone 최신 버전',
            databaseKey: 'iosLatest',
            icon: Icons.phone_iphone_rounded,
            validator: _requiredVersionValidator,
          ),
          const SizedBox(height: 12),
          _buildVersionField(
            controller: _latestController,
            label: '공통 fallback 버전',
            databaseKey: 'latest',
            icon: Icons.public_rounded,
            validator: _optionalVersionValidator,
          ),
        ],
      ),
    );
  }

  Widget _buildVersionField({
    required TextEditingController controller,
    required String label,
    required String databaseKey,
    required IconData icon,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_isSaving,
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.next,
      validator: validator,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        prefixIcon: Icon(icon, color: _accent),
        labelText: label,
        helperText: 'VERSION/$databaseKey',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE7E2DC)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE7E2DC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _accent, width: 1.4),
        ),
      ),
    );
  }
}

class _VersionSummaryCard extends StatelessWidget {
  const _VersionSummaryCard({
    required this.currentVersionLabel,
    required this.platformLabel,
  });

  final String currentVersionLabel;
  final String platformLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7E2DC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.system_update_alt_outlined,
                color: _AdminVersionManageScreenState._accent,
              ),
              const SizedBox(width: 8),
              Text(
                'Realtime Database / VERSION',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _VersionChip(
                icon: Icons.install_mobile_rounded,
                text: '현재 $platformLabel 버전 $currentVersionLabel',
              ),
              const _VersionChip(
                icon: Icons.storage_rounded,
                text: 'androidLatest / iosLatest / latest',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickApplyCard extends StatelessWidget {
  const _QuickApplyCard({
    required this.currentVersion,
    required this.platformLabel,
    required this.onApplyPlatform,
    required this.onApplyLatest,
    required this.onApplyAll,
  });

  final String currentVersion;
  final String platformLabel;
  final VoidCallback onApplyPlatform;
  final VoidCallback onApplyLatest;
  final VoidCallback onApplyAll;

  @override
  Widget build(BuildContext context) {
    final enabled = currentVersion.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7D5C3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '현재 버전으로 맞추기',
            style: TextStyle(
              color: Color(0xFF1D212C),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: enabled ? onApplyPlatform : null,
                icon: const Icon(Icons.my_location_rounded),
                label: Text('$platformLabel 적용'),
              ),
              OutlinedButton.icon(
                onPressed: enabled ? onApplyLatest : null,
                icon: const Icon(Icons.public_rounded),
                label: const Text('latest 적용'),
              ),
              OutlinedButton.icon(
                onPressed: enabled ? onApplyAll : null,
                icon: const Icon(Icons.done_all_rounded),
                label: const Text('전체 적용'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VersionChip extends StatelessWidget {
  const _VersionChip({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F1EC),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: _AdminVersionManageScreenState._accent,
            ),
            const SizedBox(width: 5),
            Text(
              text,
              style: const TextStyle(
                color: Color(0xFF5F5142),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VersionErrorState extends StatelessWidget {
  const _VersionErrorState({
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 36,
            ),
            const SizedBox(height: 12),
            Text(
              '버전 정보를 불러오지 못했습니다.\n$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}

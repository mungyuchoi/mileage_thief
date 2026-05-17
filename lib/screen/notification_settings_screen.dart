import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../services/notification_preference_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  Map<String, bool> _preferences =
      Map<String, bool>.from(NotificationPreferenceService.defaultPreferences);
  bool _loading = true;
  String? _savingKey;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final preferences = await NotificationPreferenceService.loadPreferences();
      if (!mounted) return;
      setState(() {
        _preferences = preferences;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      Fluttertoast.showToast(msg: '알림 설정을 불러오지 못했습니다.');
    }
  }

  Future<void> _setPreference(String key, bool value) async {
    setState(() {
      _preferences = {
        ..._preferences,
        key: value,
      };
      _savingKey = key;
    });

    try {
      final preferences =
          await NotificationPreferenceService.setPreference(key, value);
      if (!mounted) return;
      setState(() {
        _preferences = preferences;
        _savingKey = null;
      });
      Fluttertoast.showToast(msg: value ? '알림을 켰습니다.' : '알림을 껐습니다.');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _preferences = {
          ..._preferences,
          key: !value,
        };
        _savingKey = null;
      });
      Fluttertoast.showToast(msg: '알림 설정 저장에 실패했습니다.');
    }
  }

  bool _enabled(String key) => _preferences[key] ?? true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F1F5),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 36),
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Color(0xFF1A1D27),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Text(
                        '알림 설정',
                        style: TextStyle(
                          color: Color(0xFF1A1D27),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const _NotificationSectionLabel('커뮤니티 활동'),
                  const SizedBox(height: 6),
                  _NotificationSection(
                    children: [
                      _NotificationSwitchTile(
                        icon: Icons.thumb_up_outlined,
                        title: '내 게시글 좋아요',
                        subtitle: '내 글에 좋아요가 눌렸을 때',
                        value: _enabled(
                            NotificationPreferenceService.communityPostLike),
                        busy: _savingKey ==
                            NotificationPreferenceService.communityPostLike,
                        onChanged: (value) => _setPreference(
                          NotificationPreferenceService.communityPostLike,
                          value,
                        ),
                      ),
                      _NotificationSwitchTile(
                        icon: Icons.comment_outlined,
                        title: '내 게시글 댓글',
                        subtitle: '내 글에 새 댓글이 달렸을 때',
                        value: _enabled(
                            NotificationPreferenceService.communityPostComment),
                        busy: _savingKey ==
                            NotificationPreferenceService.communityPostComment,
                        onChanged: (value) => _setPreference(
                          NotificationPreferenceService.communityPostComment,
                          value,
                        ),
                      ),
                      _NotificationSwitchTile(
                        icon: Icons.reply_outlined,
                        title: '내 댓글 답글',
                        subtitle: '내 댓글에 답글이 달렸을 때',
                        value: _enabled(NotificationPreferenceService
                            .communityCommentReply),
                        busy: _savingKey ==
                            NotificationPreferenceService.communityCommentReply,
                        onChanged: (value) => _setPreference(
                          NotificationPreferenceService.communityCommentReply,
                          value,
                        ),
                      ),
                      _NotificationSwitchTile(
                        icon: Icons.favorite_border_outlined,
                        title: '내 댓글 좋아요',
                        subtitle: '내 댓글에 좋아요가 눌렸을 때',
                        value: _enabled(
                            NotificationPreferenceService.communityCommentLike),
                        busy: _savingKey ==
                            NotificationPreferenceService.communityCommentLike,
                        onChanged: (value) => _setPreference(
                          NotificationPreferenceService.communityCommentLike,
                          value,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const _NotificationSectionLabel('마일캐치 레이더'),
                  const SizedBox(height: 6),
                  _NotificationSection(
                    children: [
                      _NotificationSwitchTile(
                        icon: Icons.radar_outlined,
                        title: '레이더 전체',
                        subtitle: '저장한 레이더 조건 매칭 알림',
                        value: _enabled(NotificationPreferenceService.radarAll),
                        busy: _savingKey ==
                            NotificationPreferenceService.radarAll,
                        onChanged: (value) => _setPreference(
                          NotificationPreferenceService.radarAll,
                          value,
                        ),
                      ),
                      _NotificationSwitchTile(
                        icon: Icons.airline_seat_recline_extra_outlined,
                        title: '마일리지 좌석',
                        subtitle: '대한항공/아시아나 좌석 조건 매칭',
                        value: _enabled(
                            NotificationPreferenceService.radarMileageSeat),
                        busy: _savingKey ==
                            NotificationPreferenceService.radarMileageSeat,
                        onChanged: (value) => _setPreference(
                          NotificationPreferenceService.radarMileageSeat,
                          value,
                        ),
                      ),
                      _NotificationSwitchTile(
                        icon: Icons.event_available_outlined,
                        title: '취소표 관심 구간',
                        subtitle: '관심 구간 수요가 갱신될 때',
                        value: _enabled(
                            NotificationPreferenceService.radarCancelAlert),
                        busy: _savingKey ==
                            NotificationPreferenceService.radarCancelAlert,
                        onChanged: (value) => _setPreference(
                          NotificationPreferenceService.radarCancelAlert,
                          value,
                        ),
                      ),
                      _NotificationSwitchTile(
                        icon: Icons.flight_takeoff_outlined,
                        title: '항공권 특가',
                        subtitle: '조건에 맞는 항공 특가가 갱신될 때',
                        value: _enabled(
                            NotificationPreferenceService.radarFlightDeal),
                        busy: _savingKey ==
                            NotificationPreferenceService.radarFlightDeal,
                        onChanged: (value) => _setPreference(
                          NotificationPreferenceService.radarFlightDeal,
                          value,
                        ),
                      ),
                      _NotificationSwitchTile(
                        icon: Icons.redeem_outlined,
                        title: '상품권 시세',
                        subtitle: '상품권 시세 조건이 맞을 때',
                        value: _enabled(
                            NotificationPreferenceService.radarGiftcard),
                        busy: _savingKey ==
                            NotificationPreferenceService.radarGiftcard,
                        onChanged: (value) => _setPreference(
                          NotificationPreferenceService.radarGiftcard,
                          value,
                        ),
                      ),
                      _NotificationSwitchTile(
                        icon: Icons.campaign_outlined,
                        title: '혜택/정보성 글',
                        subtitle: '혜택 게시판 새 정보가 조건에 맞을 때',
                        value: _enabled(
                            NotificationPreferenceService.radarBenefitNews),
                        busy: _savingKey ==
                            NotificationPreferenceService.radarBenefitNews,
                        onChanged: (value) => _setPreference(
                          NotificationPreferenceService.radarBenefitNews,
                          value,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      '꺼진 항목은 푸시만 중단되며 알림함 기록은 유지됩니다.',
                      style: TextStyle(
                        color: Color(0xFF8A91A1),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _NotificationSection extends StatelessWidget {
  const _NotificationSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              const Divider(
                height: 8,
                indent: 52,
                color: Color(0xFFE9EBF0),
              ),
          ],
        ],
      ),
    );
  }
}

class _NotificationSectionLabel extends StatelessWidget {
  const _NotificationSectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF7E8492),
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _NotificationSwitchTile extends StatelessWidget {
  const _NotificationSwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.busy = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      minLeadingWidth: 32,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      leading: Icon(icon, color: const Color(0xFFAEB4C0)),
      title: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF1D212C),
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                subtitle!,
                style: const TextStyle(
                  color: Color(0xFF8A91A1),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
      trailing: busy
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Switch.adaptive(
              value: value,
              activeThumbColor: Colors.black,
              activeTrackColor: Colors.black26,
              onChanged: onChanged,
            ),
      onTap: busy ? null : () => onChanged(!value),
    );
  }
}

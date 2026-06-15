import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/hotel_catch_service.dart';

/// 호텔 캐치 — 퀴즈 작성(앱 풀기능: OX / 객관식 / 주관식).
class HotelQuizCreateScreen extends StatefulWidget {
  const HotelQuizCreateScreen({
    super.key,
    required this.hotelId,
    required this.hotelName,
    this.quiz,
  });

  final String hotelId;
  final String hotelName;

  /// 비어 있으면 신규 작성, 있으면 수정 모드.
  final HotelQuizItem? quiz;

  @override
  State<HotelQuizCreateScreen> createState() => _HotelQuizCreateScreenState();
}

const List<List<String>> _tags = <List<String>>[
  <String>['honeymoon', '🍯 신혼각'],
  <String>['parents', '👨‍👩‍👧 효도각'],
  <String>['view', '🌊 뷰맛집'],
  <String>['value', '💸 가성비'],
  <String>['upgrade', '🛎️ 업글'],
  <String>['general', '📌 일반'],
];

class _HotelQuizCreateScreenState extends State<HotelQuizCreateScreen> {
  String _type = 'ox'; // ox | mcq | short
  String _tag = 'general';
  final TextEditingController _question = TextEditingController();
  final TextEditingController _explanation = TextEditingController();
  final TextEditingController _shortAnswer = TextEditingController();
  bool _oxAnswer = true; // true=O
  final List<TextEditingController> _options =
      List<TextEditingController>.generate(4, (_) => TextEditingController());
  int _correctIndex = 0;
  bool _saving = false;

  bool get _editing => widget.quiz != null;

  @override
  void initState() {
    super.initState();
    final q = widget.quiz;
    if (q != null) {
      _type = q.type;
      _tag = q.tag;
      _question.text = q.question;
      _explanation.text = q.explanation;
      if (q.type == 'ox') {
        _oxAnswer = q.answer == true;
      } else if (q.type == 'mcq') {
        for (var i = 0; i < 4 && i < q.options.length; i++) {
          _options[i].text = q.options[i];
        }
        final a = q.answer;
        _correctIndex = a is int ? a : (a is num ? a.toInt() : 0);
      } else {
        _shortAnswer.text = q.answer?.toString() ?? '';
      }
    }
  }

  @override
  void dispose() {
    _question.dispose();
    _explanation.dispose();
    _shortAnswer.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _canSubmit {
    if (_saving) return false;
    if (_question.text.trim().length < 3) return false;
    if (_type == 'short') return _shortAnswer.text.trim().isNotEmpty;
    if (_type == 'mcq') {
      final filled = _options.where((c) => c.text.trim().isNotEmpty).length;
      return filled >= 2 && _options[_correctIndex].text.trim().isNotEmpty;
    }
    return true; // ox
  }

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _toast('로그인이 필요해요');
      return;
    }
    setState(() => _saving = true);
    try {
      Object answer;
      List<String> options = const <String>[];
      if (_type == 'ox') {
        answer = _oxAnswer;
      } else if (_type == 'mcq') {
        options = _options.map((c) => c.text.trim()).toList();
        answer = _correctIndex;
      } else {
        answer = _shortAnswer.text.trim();
      }
      if (_editing) {
        await HotelCatchService.instance.updateQuiz(
          hotelId: widget.hotelId,
          quizId: widget.quiz!.id,
          type: _type,
          tag: _tag,
          question: _question.text,
          options: options,
          answer: answer,
          explanation: _explanation.text,
        );
      } else {
        await HotelCatchService.instance.createQuiz(
          hotelId: widget.hotelId,
          type: _type,
          tag: _tag,
          question: _question.text,
          options: options,
          answer: answer,
          explanation: _explanation.text,
          authorUid: user.uid,
          authorNickname: user.displayName ?? '여행자',
        );
      }
      if (!mounted) return;
      _toast(_editing ? '퀴즈 수정 완료 ✦' : '퀴즈 등록 완료 ✦');
      Navigator.of(context).pop(true);
    } catch (e) {
      _toast(_editing ? '퀴즈 수정에 실패했어요' : '퀴즈 등록에 실패했어요');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text('${_editing ? '퀴즈 수정' : '퀴즈 내기'} · '
              '${widget.hotelName}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: <Widget>[
          _label('퀴즈 유형'),
          Wrap(spacing: 8, children: <Widget>[
            _typeChip('ox', 'OX'),
            _typeChip('mcq', '객관식'),
            _typeChip('short', '주관식'),
          ]),
          const SizedBox(height: 16),
          _label('상황 태그'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tags
                .map((t) => ChoiceChip(
                      label: Text(t[1]),
                      selected: _tag == t[0],
                      onSelected: (_) => setState(() => _tag = t[0]),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          _label('문제'),
          TextField(
            controller: _question,
            maxLines: 2,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '예: 이 호텔은 조식이 무료다.',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          ..._answerSection(),
          const SizedBox(height: 16),
          _label('해설 (선택)'),
          TextField(
            controller: _explanation,
            maxLines: 2,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '정답 이유…',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _canSubmit ? _submit : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_saving
                  ? '저장 중…'
                  : (_editing ? '수정 저장' : '퀴즈 등록')),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _answerSection() {
    if (_type == 'ox') {
      return <Widget>[
        _label('정답'),
        Row(children: <Widget>[
          Expanded(child: _oxBtn(true, 'O')),
          const SizedBox(width: 8),
          Expanded(child: _oxBtn(false, 'X')),
        ]),
      ];
    }
    if (_type == 'mcq') {
      return <Widget>[
        _label('보기 (정답 라디오 선택)'),
        ...List<Widget>.generate(4, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: <Widget>[
              Radio<int>(
                value: i,
                groupValue: _correctIndex,
                onChanged: (v) => setState(() => _correctIndex = v ?? 0),
              ),
              Expanded(
                child: TextField(
                  controller: _options[i],
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    hintText: '보기 ${i + 1}',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ]),
          );
        }),
      ];
    }
    return <Widget>[
      _label('정답 (주관식)'),
      TextField(
        controller: _shortAnswer,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          hintText: '정확한 정답 텍스트',
        ),
        onChanged: (_) => setState(() {}),
      ),
    ];
  }

  Widget _typeChip(String value, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _type == value,
      onSelected: (_) => setState(() => _type = value),
    );
  }

  Widget _oxBtn(bool value, String label) {
    final bool on = _oxAnswer == value;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: on ? Colors.black : null,
        foregroundColor: on ? Colors.white : Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      onPressed: () => setState(() => _oxAnswer = value),
      child: Text(label, style: const TextStyle(fontSize: 20)),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/hotel_catch_service.dart';
import 'hotel_quiz_create_screen.dart';

/// 호텔 캐치 — 내가 기여한(추가한) 호텔 목록 → 퀴즈 추가 진입.
class HotelCatchScreen extends StatelessWidget {
  const HotelCatchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('호텔 캐치 · 내 호텔')),
      body: user == null
          ? const Center(child: Text('로그인이 필요해요'))
          : StreamBuilder<List<HotelCatchHotel>>(
              stream: HotelCatchService.instance.myHotels(user.uid),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final hotels = snap.data ?? const <HotelCatchHotel>[];
                if (hotels.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        '아직 추가한 호텔이 없어요.\n'
                        '세계지도에서 호텔을 추가하면 여기에 표시됩니다.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: hotels.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final h = hotels[i];
                    return ListTile(
                      leading: const Icon(Icons.apartment),
                      title: Text(h.name.isEmpty ? '이름 없는 호텔' : h.name),
                      subtitle: Text(h.city),
                      trailing: const Icon(Icons.add_circle_outline),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<bool>(
                          builder: (_) => HotelQuizCreateScreen(
                            hotelId: h.id,
                            hotelName: h.name,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

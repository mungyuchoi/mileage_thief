import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'branch_step2.dart';

class BranchStep1Page extends StatefulWidget {
  const BranchStep1Page({super.key});

  @override
  State<BranchStep1Page> createState() => _BranchStep1PageState();
}

class _BranchStep1PageState extends State<BranchStep1Page> {
  final Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();
  CameraPosition _camera = const CameraPosition(target: LatLng(37.5665, 126.9780), zoom: 15);
  bool _locationEnabled = false;
  String _address = '';
  final TextEditingController _detailAddressController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      LocationPermission granted = permission;
      if (permission == LocationPermission.denied) {
        granted = await Geolocator.requestPermission();
      }
      if (granted == LocationPermission.deniedForever) {
        setState(() { _locationEnabled = false; });
        return;
      }
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() { _locationEnabled = false; });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final cp = CameraPosition(target: LatLng(pos.latitude, pos.longitude), zoom: 16);
      setState(() {
        _locationEnabled = true;
        _camera = cp;
      });
      final controller = await _mapController.future;
      await controller.animateCamera(CameraUpdate.newCameraPosition(cp));
      _reverseGeocode(pos.latitude, pos.longitude);
    } catch (_) {}
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&accept-language=ko');
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 6);
      final req = await client.getUrl(uri);
      req.headers.set(HttpHeaders.userAgentHeader, 'MileageThief/1.0 (reverse-geocode)');
      final resp = await req.close();
      if (resp.statusCode != 200) return;
      final body = await resp.transform(const Utf8Decoder()).join();
      final Map<String, dynamic> json = jsonDecode(body) as Map<String, dynamic>;
      setState(() {
        _address = (json['display_name'] as String?) ?? '';
      });
    } catch (_) {}
  }

  void _onCameraMove(CameraPosition pos) {
    _camera = pos;
  }

  void _onCameraIdle() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () {
      _reverseGeocode(_camera.target.latitude, _camera.target.longitude);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _detailAddressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF74512D),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '플레이스의\n정보를 알려주세요',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.black),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 1.2,
                  child: Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: _camera,
                        myLocationEnabled: _locationEnabled,
                        myLocationButtonEnabled: true,
                        onMapCreated: (c) {
                          if (!_mapController.isCompleted) {
                            _mapController.complete(c);
                          }
                        },
                        onCameraMove: _onCameraMove,
                        onCameraIdle: _onCameraIdle,
                      ),
                      Center(
                        child: IgnorePointer(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.location_on, color: Color(0xFF74512D), size: 40),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _address.isEmpty ? '주소를 불러오는 중...' : _address,
                style: const TextStyle(fontSize: 14, color: Colors.black),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _detailAddressController,
                decoration: InputDecoration(
                  hintText: '(선택) 상세 주소 입력',
                  hintStyle: const TextStyle(color: Colors.black38),
                  filled: true,
                  fillColor: Colors.white,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE6E6E9)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF74512D), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BranchStep2Page(
                          latitude: _camera.target.latitude,
                          longitude: _camera.target.longitude,
                          address: _address,
                          detailAddress: _detailAddressController.text.trim(),
                        ),
                      ),
                    );
                    if (result == true && mounted) {
                      Navigator.pop(context, true); // 스텝1까지 닫기
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF74512D),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('다음', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}



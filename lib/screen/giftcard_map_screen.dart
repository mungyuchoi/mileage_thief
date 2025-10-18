import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GiftcardMapScreen extends StatefulWidget {
  const GiftcardMapScreen({super.key});

  @override
  State<GiftcardMapScreen> createState() => _GiftcardMapScreenState();
}

class _GiftcardMapScreenState extends State<GiftcardMapScreen> {
  final Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();
  CameraPosition _initialCamera = const CameraPosition(
    target: LatLng(37.5665, 126.9780), // 서울시청 근처 기본값
    zoom: 12,
  );
  bool _locationEnabled = false;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    final permission = await Geolocator.checkPermission();
    LocationPermission granted = permission;
    if (permission == LocationPermission.denied) {
      granted = await Geolocator.requestPermission();
    }
    if (granted == LocationPermission.deniedForever) {
      setState(() {
        _locationEnabled = false;
      });
      return;
    }
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _locationEnabled = false;
      });
      return;
    }
    try {
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _locationEnabled = true;
        _initialCamera = CameraPosition(target: LatLng(position.latitude, position.longitude), zoom: 15);
      });
      final controller = await _mapController.future;
      await controller.animateCamera(CameraUpdate.newCameraPosition(_initialCamera));
    } catch (_) {
      setState(() {
        _locationEnabled = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: _initialCamera,
          myLocationEnabled: _locationEnabled,
          myLocationButtonEnabled: true,
          compassEnabled: true,
          trafficEnabled: false,
          onMapCreated: (controller) {
            if (!_mapController.isCompleted) {
              _mapController.complete(controller);
            }
          },
        ),
        // 살짝 하얀 블러 느낌의 오버레이 (터치 방해 없음)
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              color: Colors.white.withOpacity(0.15),
            ),
          ),
        ),
        // 안내 문구 (터치 방해 없도록)
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    '👷‍♂️⚠️🚧 상품권 지도/정보',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '현재 위치는 흐리게 표시됩니다',
                    style: TextStyle(color: Colors.black87, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}



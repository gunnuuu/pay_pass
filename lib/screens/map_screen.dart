import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pay_pass/screens/simple_log_screen.dart';
import 'package:pay_pass/utils/geofence_service.dart';
import 'package:pay_pass/utils/location_service.dart';
import 'package:pay_pass/screens/notice_screen.dart';
import 'package:pay_pass/screens/mypage_screen.dart';
import 'package:pay_pass/variables/globals.dart';
import 'package:pay_pass/variables/constants.dart';
import 'package:pay_pass/utils/logger.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final LocationService _locationService = LocationService();
  LatLng? _currentPosition;
  final Set<Circle> _circles = {}; // Geofence 영역 표시용

  @override
  void initState() {
    super.initState();
    setupGeofenceService();
    _initializeLocationService();
    _showNoticeDialogIfNeeded(); // 공지사항 다이얼로그 출력
  }

  // LocationService 초기화  -> 얘만 페이지별로 추가해주고 initState에 추가하여 호출시 동작 가능능
  Future<void> _initializeLocationService() async {
    await _locationService.enableLocationServices();
    await _locationService.initializeWebSocket('ws://${Constants.ip}/location');

    _locationService.startListening((position) {
      setState(() {
        _currentPosition = position;
      });

      // 지오펜싱 확인
      final isNearStation = _locationService.checkGeofence(
        stations,
        position.latitude,
        position.longitude,
      );

      if (isNearStation) {
        logger.i("정류장 근처입니다");
      } else {
        logger.i("정류장 근처가 아님");
      }
    });
  }

  // 공지사항 출력 관련
  Future<void> _showNoticeDialogIfNeeded() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await NoticeScreen.show(context); // 공지사항 Dialog 호출
    });
  }

  // 지도에 지오펜싱 영역 추가
  void _addGeofenceZonesToMap() {
    for (var station in stations) {
      final circle = Circle(
        circleId: CircleId(station['stationNumber'].toString()),
        center: LatLng(station['latitude'], station['longitude']),
        radius: 100, // 100m
        fillColor: const Color.fromARGB(255, 101, 182, 248)
            .withAlpha((0.4 * 255).toInt()), // 0.4 투명도
        strokeColor: Colors.blue,
        strokeWidth: 2,
      );

      setState(() {
        _circles.add(circle);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Stack(
          children: [
            Positioned(
              top: 40,
              left: 20,
              child: Image.asset(
                'assets/logo.png',
                width: 40,
              ),
            ),
          ],
        ),
      ),
      body: _currentPosition == null
          ? Center(child: CircularProgressIndicator())
          : GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentPosition!,
                zoom: 16,
              ),
              markers: stations
                  .map((station) => Marker(
                        markerId: MarkerId(station['stationNumber'].toString()),
                        position:
                            LatLng(station['latitude'], station['longitude']),
                        infoWindow: InfoWindow(
                          title: '정류장 ${station['name']}',
                        ),
                      ))
                  .toSet(),
              circles: _circles,
              onMapCreated: (GoogleMapController controller) {
                _controller.complete(controller);
                _addGeofenceZonesToMap();
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
            ),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: '지도'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: '활동 로그'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '마이페이지'),
        ],
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => MapScreen()),
              );
              break;
            case 1:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => SimpleLogScreen()),
              );
              break;
            case 2:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => MyPageScreen()),
              );
              break;
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _locationService.dispose(); // 리소스 정리
    super.dispose();
  }
}

import 'dart:convert';

import 'package:geofence_foreground_service/constants/geofence_event_type.dart';
import 'package:geofence_foreground_service/exports.dart';
import 'package:geofence_foreground_service/geofence_foreground_service.dart';
import 'package:geofence_foreground_service/models/zone.dart';

import 'package:latlng/latlng.dart';
import 'package:http/http.dart' as http;

import 'package:pay_pass/utils/logger.dart';
import 'package:pay_pass/variables/constants.dart';
import 'package:pay_pass/variables/globals.dart';

@pragma('vm:entry-point')
void callbackDispatcher() async {
  GeofenceForegroundService().handleTrigger(
    backgroundTriggerHandler: (zoneID, triggerType) {
      if (triggerType == GeofenceEventType.enter) {
        logger.i('$globalGoogleId Entered geofence: $zoneID'); // 데이터 저장 로직으로 변경
        userFenceIn(zoneID);
      } else if (triggerType == GeofenceEventType.exit) {
        logger.i('$globalGoogleId Exited geofence: $zoneID'); // 데이터 수정 로직으로 변경
        userFenceOut(zoneID);
      } else if (triggerType == GeofenceEventType.dwell) {
        logger.i('$globalGoogleId Dwelled geofence: $zoneID');
      } else {
        logger.i('$globalGoogleId Unknown type in geofence');
      }
      return Future.value(true);
    },
  );
}

Future<void> userFenceIn(zoneID) async {
  //zoneID의 출력값은 stationNumber값이다.
  final response = await http.post(
    Uri.parse('http://${Constants.ip}/userFenceIn'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      // stationNumber 값이랑 mainId 넘기기기
      'mainId': globalGoogleId,
      'stationNumber': zoneID
    }),
  );

  if (response.statusCode == 200) {
    logger.i("geofenceLocation enetity를 성공적으로 생성하였습니다.");
  }
}

Future<void> userFenceOut(zoneID) async {
  final response = await http.post(
    Uri.parse('http://${Constants.ip}/userFenceOut'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'mainId': globalGoogleId, 'stationNumber': zoneID}),
  );

  if (response.statusCode == 200) {
    logger.i("geofenceLocation entity의 fenceOutTime을 성공적으로 추가하였습니다.");
  }
}

void setupGeofenceService() async {
  await GeofenceForegroundService().startGeofencingService(
    contentTitle: 'Geofencing Active',
    contentText: 'Monitoring geofence zones.',
    serviceId: 1000,
    notificationChannelId: 'com.app.geofencing_notifications_channel',
    callbackDispatcher: callbackDispatcher,
  );

  for (var station in stations) {
    final zone = Zone(
      id: station['stationNumber'].toString(),
      radius: 100, //100m
      coordinates: [
        LatLng(Angle.degree(station['latitude']),
            Angle.degree(station['longitude']))
      ],
    );

    await GeofenceForegroundService().addGeofenceZone(zone: zone);
  }
}

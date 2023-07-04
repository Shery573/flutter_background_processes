import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../Controllers/myController.dart';

class BackgroundServiceManager {
  final FlutterBackgroundService _service = FlutterBackgroundService();

  // Move the FlutterLocalNotificationsPlugin instance here
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  BackgroundServiceManager();

  Future<void> initialize() async {
    final AndroidNotificationChannel channel = AndroidNotificationChannel(
      'my_foreground',
      'MY FOREGROUND SERVICE',
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
    );

    if (Platform.isIOS || Platform.isAndroid) {
      await flutterLocalNotificationsPlugin.initialize(
        const InitializationSettings(
          iOS: DarwinInitializationSettings(requestCriticalPermission: true),
          android: AndroidInitializationSettings('ic_bg_service_small'),
        ),
      );
    }

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'my_foreground',
        initialNotificationTitle: 'AWESOME SERVICE',
        initialNotificationContent: 'Initializing',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    _service.startService();
  }

////
  Future<String> fetchData() async {
    var response = await http
        .get(Uri.parse('https://jsonplaceholder.typicode.com/todos/1'));
    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      var fieldData = data['id'].toString();
      // Update the observable variable in MyController
      return fieldData;
    } else {
      throw Exception('Failed to load data');
    }
  }

  FlutterBackgroundService get service => _service;
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();

  SharedPreferences preferences = await SharedPreferences.getInstance();
  await preferences.reload();
  final log = preferences.getStringList('log') ?? <String>[];
  log.add(DateTime.now().toIso8601String());
  await preferences.setStringList('log', log);

  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  SharedPreferences preferences = await SharedPreferences.getInstance();
  await preferences.setString("hello", "world");

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Create an instance of BackgroundServiceManager
  final BackgroundServiceManager bgManager = BackgroundServiceManager();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    Timer.periodic(const Duration(seconds: 1), (timer) async {
      // Use fetchData() from the BackgroundServiceManager
      var data = await bgManager.fetchData();
      // Get.put(MyController()).updateData(data);
      if (await service.isForegroundService()) {
        // Updating the Notification
        flutterLocalNotificationsPlugin.show(
          888,
          'COOL SERVICE',
          'Data: $data',
          const NotificationDetails(
            android: AndroidNotificationDetails(
                'my_foreground', 'MY FOREGROUND SERVICE',
                icon: 'ic_bg_service_small', ongoing: false, playSound: false),
          ),
        );
      }

      print('FLUTTER BACKGROUND SERVICE: ${DateTime.now()}');

      final deviceInfo = DeviceInfoPlugin();
      String? device;
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        device = androidInfo.model;
      }

      if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        device = iosInfo.model;
      }

      service.invoke(
        'update',
        {
          "current_date": DateTime.now().toIso8601String(),
          "device": device,
          "data": data, // Pass the fetched data
        },
      );
    });
  }
}

// import 'dart:async';
// import 'dart:io';

// import 'package:device_info_plus/device_info_plus.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_background_service/flutter_background_service.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// class BackgroundServiceManager {
//   final FlutterBackgroundService _service = FlutterBackgroundService();

//   BackgroundServiceManager();

//   Future<void> initialize() async {
//     final AndroidNotificationChannel channel = AndroidNotificationChannel(
//       'my_foreground',
//       'MY FOREGROUND SERVICE',
//       description: 'This channel is used for important notifications.',
//       importance: Importance.high,
//     );

//     final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
//         FlutterLocalNotificationsPlugin();

//     if (Platform.isIOS || Platform.isAndroid) {
//       await flutterLocalNotificationsPlugin.initialize(
//         const InitializationSettings(
//           iOS: DarwinInitializationSettings(requestCriticalPermission: true),
//           android: AndroidInitializationSettings('ic_bg_service_small'),
//         ),
//       );
//     }

//     await flutterLocalNotificationsPlugin
//         .resolvePlatformSpecificImplementation<
//             AndroidFlutterLocalNotificationsPlugin>()
//         ?.createNotificationChannel(channel);

//     await _service.configure(
//       androidConfiguration: AndroidConfiguration(
//         onStart: onStart,
//         autoStart: true,
//         isForegroundMode: true,
//         notificationChannelId: 'my_foreground',
//         initialNotificationTitle: 'AWESOME SERVICE',
//         initialNotificationContent: 'Initializing',
//         foregroundServiceNotificationId: 888,
//       ),
//       iosConfiguration: IosConfiguration(
//         autoStart: true,
//         onForeground: onStart,
//         onBackground: onIosBackground,
//       ),
//     );

//     _service.startService();
//   }

//   FlutterBackgroundService get service => _service;
// }

// @pragma('vm:entry-point')
// Future<bool> onIosBackground(ServiceInstance service) async {
//   WidgetsFlutterBinding.ensureInitialized();

//   SharedPreferences preferences = await SharedPreferences.getInstance();
//   await preferences.reload();
//   final log = preferences.getStringList('log') ?? <String>[];
//   log.add(DateTime.now().toIso8601String());
//   await preferences.setStringList('log', log);

//   return true;
// }

// @pragma('vm:entry-point')
// void onStart(ServiceInstance service) async {
//   DartPluginRegistrant.ensureInitialized();
//   SharedPreferences preferences = await SharedPreferences.getInstance();
//   await preferences.setString("hello", "world");

//   final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
//       FlutterLocalNotificationsPlugin();

//   if (service is AndroidServiceInstance) {
//     service.on('setAsForeground').listen((event) {
//       service.setAsForegroundService();
//     });

//     service.on('setAsBackground').listen((event) {
//       service.setAsBackgroundService();
//     });

//     service.on('stopService').listen((event) {
//       service.stopSelf();
//     });

//     Timer.periodic(const Duration(seconds: 1), (timer) async {
//       if (await service.isForegroundService()) {
//         flutterLocalNotificationsPlugin.show(
//           888,
//           'COOL SERVICE',
//           'Awesome ${DateTime.now()}',
//           const NotificationDetails(
//             android: AndroidNotificationDetails(
//               'my_foreground',
//               'MY FOREGROUND SERVICE',
//               icon: 'ic_bg_service_small',
//               ongoing: true,
//             ),
//           ),
//         );
//       }

//       print('FLUTTER BACKGROUND SERVICE: ${DateTime.now()}');

//       final deviceInfo = DeviceInfoPlugin();
//       String? device;
//       if (Platform.isAndroid) {
//         final androidInfo = await deviceInfo.androidInfo;
//         device = androidInfo.model;
//       }

//       if (Platform.isIOS) {
//         final iosInfo = await deviceInfo.iosInfo;
//         device = iosInfo.model;
//       }

//       service.invoke(
//         'update',
//         {
//           "current_date": DateTime.now().toIso8601String(),
//           "device": device,
//         },
//       );
//     });
//   }
// }

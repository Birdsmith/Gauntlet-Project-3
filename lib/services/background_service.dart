import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class BackgroundService {
  static Future<void> initializeService() async {
    if (kIsWeb) return; // Skip initialization on web platform
    
    final service = FlutterBackgroundService();

    // Configure Android-specific settings
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'gauntlet_background_service',
        initialNotificationTitle: 'Gauntlet Background Service',
        initialNotificationContent: 'Initializing',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    if (kIsWeb) return true; // No-op for web
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    if (kIsWeb) return; // No-op for web
    
    DartPluginRegistrant.ensureInitialized();

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // Add your background task logic here
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          // Update notification content
          service.setForegroundNotificationInfo(
            title: "Gauntlet Background Service",
            content: "Running in background: ${DateTime.now()}",
          );
        }
      }

      // Send data to your app UI if necessary
      service.invoke(
        'update',
        {
          "current_date": DateTime.now().toIso8601String(),
          "device": "Android",
        },
      );
    });
  }

  static Future<void> startService() async {
    if (kIsWeb) return; // No-op for web
    final service = FlutterBackgroundService();
    await service.startService();
  }

  static Future<void> stopService() async {
    if (kIsWeb) return; // No-op for web
    final service = FlutterBackgroundService();
    service.invoke('stopService');
  }
} 
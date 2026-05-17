import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pushnotification/firebase_options.dart';

@pragma('vm:entry-point')
class NotificationService {
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;

  // নোটিফিকেশন চ্যানেলের জন্য কনস্ট্যান্ট ভ্যারিয়েবল
  static const String _channelId = 'app_push_notification_channel';
  static const String _channelName = 'High Importance Notifications';
  static const String _channelDesc =
      'This channel is used for important app notifications.';

  // অ্যাপটি ফোরগ্রাউন্ডে আছে কিনা তা ট্র্যাক করার জন্য একটি ফ্ল্যাগ (Flag)
  static bool _isAppInForeground = false;

  /// ইমেজ ডাউনলোড করে লোকাল পাথে সেভ করার মেথড
  static Future<String> _downloadAndSaveFile(
      String url,
      String fileName,
      ) async {
    try {
      final Directory directory = await getApplicationDocumentsDirectory();
      final String filePath = '${directory.path}/$fileName';

      final HttpClient httpClient = HttpClient();
      final HttpClientRequest request = await httpClient.getUrl(Uri.parse(url));
      final HttpClientResponse response = await request.close();

      if (response.statusCode == 200) {
        final List<int> bytes = await response
            .expand((element) => element)
            .toList();
        final File file = File(filePath);
        await file.writeAsBytes(bytes);
        return filePath;
      }
      throw Exception(
        "Failed to download image: Status code ${response.statusCode}",
      );
    } catch (e) {
      log("Error in _downloadAndSaveFile: $e");
      rethrow;
    }
  }

  /// অ্যাপ যখন ব্যাকগ্রাউন্ড বা সম্পূর্ণ বন্ধ (Terminated) থাকে তখন এটি কাজ করে
  @pragma('vm:entry-point')
  static Future<void> firebaseMessagingBackgroundHandler(
      RemoteMessage message,
      ) async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // যেহেতু এটি ব্যাকগ্রাউন্ড হ্যান্ডলার, তাই নিশ্চিতভাবেই অ্যাপ ফোরগ্রাউন্ডে নেই
    _isAppInForeground = false;

    await _initializeLocalNotification();
    await _showFlutterNotification(message);
  }

  /// পুশ নোটিফিকেশন সিস্টেমের মেইন ইনিশিয়ালাইজেশন
  static Future<void> initializeNotification() async {
    // অ্যাপ চালু হওয়া মানেই এটি ফোরগ্রাউন্ডে আছে
    _isAppInForeground = true;

    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // অ্যাপ ফোরগ্রাউন্ডে (ওপেন) থাকা অবস্থায় নোটিফিকেশন আসলে
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      log("Foreground notification received: ${message.messageId}");
      _isAppInForeground = true; // নিশ্চিত করা হলো
      await _showFlutterNotification(message);
    });

    // অ্যাপ ব্যাকগ্রাউন্ডে থাকা অবস্থায় নোটিফিকেশনে ট্যাপ করে ওপেন করলে
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      log("App opened from background via notification tap: ${message.data}");
      _handleNotificationClick(message.data);
    });

    await _getFcmToken();
    await _initializeLocalNotification();
    await _getInitialNotification();
  }

  static Future<void> _getFcmToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      log("FCM TOKEN: ========> $token <========");
    } catch (e) {
      log("Error getting FCM token: $e");
    }
  }

  /// নোটিফিকেশন স্ক্রিনে ডিসপ্লে করার কোর মেথড
  static Future<void> _showFlutterNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    Map<String, dynamic> data = message.data;

    if (notification == null && data.isEmpty) {
      log("Empty payload received. Skipping notification display.");
      return;
    }

    String title = notification?.title ?? data['title'] ?? "";
    String body = notification?.body ?? data['body'] ?? "";

    if (title.isEmpty && body.isEmpty) {
      log("Notification title and body both are empty. Skipping display.");
      return;
    }

    String? imageUrl =
        notification?.android?.imageUrl ?? data['image'] ?? data['imageUrl'];

    // 🌟 নতুন ডাবল নোটিফিকেশন ফিক্স লজিক (Background & Terminated দুটোর জন্যই কাজ করবে)
    // অ্যাপ যদি ফোরগ্রাউন্ডে না থাকে এবং ফায়ারবেসের নিজস্ব নোটিফিকেশন অবজেক্ট থাকে,
    // আর যদি কোনো রিচ মিডিয়া (ইমেজ) না থাকে, তবে লোকাল পুশ সম্পূর্ণ স্কিপ হবে।
    if (!_isAppInForeground &&
        notification != null &&
        (imageUrl == null || imageUrl.isEmpty)) {
      log(
        "Notification already handled by Android OS in Background/Terminated state. Skipping local duplicate.",
      );
      return;
    }

    AndroidNotificationDetails androidDetails;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        final String bigPicturePath = await _downloadAndSaveFile(
          imageUrl,
          'notification_big_picture_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );

        androidDetails = AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          priority: Priority.high,
          importance: Importance.max, // পপ-আপ হেডস-আপের জন্য Max করা হলো
          styleInformation: BigPictureStyleInformation(
            FilePathAndroidBitmap(bigPicturePath),
            contentTitle: title,
            summaryText: body,
          ),
        );
      } catch (e) {
        log(
          "Falling back to standard notification due to image download error: $e",
        );
        androidDetails = const AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          priority: Priority.high,
          importance: Importance.max,
        );
      }
    } else {
      androidDetails = const AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        priority: Priority.high,
        importance: Importance.max,
      );
    }

    DarwinNotificationDetails iosDetails = const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final int notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await flutterLocalNotificationsPlugin.show(
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: jsonEncode(data),
      id: notificationId,
    );
  }

  static Future<void> _initializeLocalNotification() async {
    const AndroidInitializationSettings androidInit =
    AndroidInitializationSettings("@drawable/notification_icon");

    const DarwinInitializationSettings iosInit = DarwinInitializationSettings();

    final InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await flutterLocalNotificationsPlugin.initialize(
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          log("User tapped notification: ${response.payload}");
          try {
            Map<String, dynamic> payloadData = jsonDecode(response.payload!);
            _handleNotificationClick(payloadData);
          } catch (e) {
            log("Error parsing notification payload: $e");
          }
        }
      },
      settings: initSettings,
    );
  }

  static Future<void> _getInitialNotification() async {
    RemoteMessage? message = await FirebaseMessaging.instance
        .getInitialMessage();
    if (message != null) {
      log(
        "App launched from completely terminated state via notification: ${message.data}",
      );
      _handleNotificationClick(message.data);
    }
  }

  static void _handleNotificationClick(Map<String, dynamic> data) {
    if (data.isEmpty) return;
    log("Handling routing logic for data: $data");
  }
}

import 'dart:developer';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pushnotification/firebase_options.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;

  static Future<String> _downloadAndSaveFile(
    String url,
    String fileName,
  ) async {
    final Directory directory = await getApplicationDocumentsDirectory();
    final String filePath = '${directory.path}/$fileName';

    final HttpClient httpClient = HttpClient();
    final HttpClientRequest request = await httpClient.getUrl(Uri.parse(url));
    final HttpClientResponse response = await request.close();
    final List<int> bytes = await response
        .expand((element) => element)
        .toList();

    final File file = File(filePath);
    await file.writeAsBytes(bytes);
    return filePath;
  }

  // handles message when the app is the background or terminated
  @pragma('vm:entry-point')
  static Future<void> firebaseMessagingBackgroundHandler(
    RemoteMessage message,
  ) async {
    // firebase must be initialized in background isolaet
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize local notification plugin and show notification
    await _showFlutterNotification(message);
    await _initializeLocalNotification();
  }

  /// Initialize Firebase messaging and local notifications
  static Future<void> initializeNotification() async {
    // Request permissions (Required on ios, Optional on android)
    await _firebaseMessaging.requestPermission();

    // called when message is received while app is foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      await _showFlutterNotification(message);
    });

    // Call when app is brought to foreground to background by tapping a notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      log("App opened from background notification: ${message.data}");
    });

    // Get and print FCM token (for sending targeted message)
    await _getFcmToken();

    // Initialize the local notification plugin
    await _initializeLocalNotification();

    // check if app was launched buy tapping on a notification
    await _getInitialNotification();
  }

  static Future<void> _getFcmToken() async {
    String? token = await _firebaseMessaging.getToken();
    log("FCM token: $token");
    //use this token to send message to this device
  }

  /// show a local notification when a message is received
  static Future<void> _showFlutterNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    Map<String, dynamic> data = message.data;

    String? title = notification?.title ?? data['title'] ?? "No Title";
    String? body = notification?.body ?? data['body'] ?? "No Body";

    // ১. ফায়ারবেস পেলোড থেকে ইমেজের লিঙ্কটি বের করা (Notification বা Data দুই জায়গা থেকেই চেক করা হচ্ছে)
    String? imageUrl =
        notification?.android?.imageUrl ?? data['image'] ?? data['imageUrl'];

    AndroidNotificationDetails androidDetails;

    // ২. যদি ইমেজ থাকে, তবে BigPictureStyle সেট করা হবে
    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        // ইমেজ ডাউনলোড করে লোকাল পাথ নেওয়া হচ্ছে
        final String bigPicturePath = await _downloadAndSaveFile(
          imageUrl,
          'notification_big_picture.jpg',
        );

        androidDetails = AndroidNotificationDetails(
          'CHANNEL_ID',
          'CHANNEL_NAME',
          channelDescription: "Notification channel for basic test",
          priority: Priority.high,
          importance: Importance.high,
          // এখানে ইমেজ সেট করা হচ্ছে
          styleInformation: BigPictureStyleInformation(
            FilePathAndroidBitmap(bigPicturePath),
            largeIcon: FilePathAndroidBitmap(
              bigPicturePath,
            ), // নোটিফিকেশনের ডানপাশে ছোট আইকন হিসেবেও দেখাবে
            contentTitle: title,
            summaryText: body,
          ),
        );
      } catch (e) {
        log("Error downloading notification image: $e");
        // কোনো কারণে ইমেজ ডাউনলোড না হলে সাধারণ টেক্সট নোটিফিকেশন দেখাবে
        androidDetails = const AndroidNotificationDetails(
          'CHANNEL_ID',
          'CHANNEL_NAME',
          channelDescription: "Notification channel for basic test",
          priority: Priority.high,
          importance: Importance.high,
        );
      }
    } else {
      // ৩. যদি কোনো ইমেজ না থাকে, তবে আগের মতোই সাধারণ নোটিফিকেশন দেখাবে
      androidDetails = const AndroidNotificationDetails(
        'CHANNEL_ID',
        'CHANNEL_NAME',
        channelDescription: "Notification channel for basic test",
        priority: Priority.high,
        importance: Importance.high,
      );
    }

    /// IOS notification config
    DarwinNotificationDetails iosDetails = const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      // iOS-এর জন্যও ইমেজ সাপোর্ট চাইলে দিতে পারেন, তবে সেটার জন্য ফ্লাটারে Notification Service Extension লাগে।
    );

    /// combine platform-specific settings
    NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    /// Show notification
    await flutterLocalNotificationsPlugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
    );
  }
  // static Future<void> _showFlutterNotification(RemoteMessage message) async {
  //   RemoteNotification? notification = message.notification;
  //   Map<String, dynamic> data = message.data;
  //
  //   String? title = notification?.title ?? data['title'] ?? "No Title";
  //   String? body = notification?.body ?? data['body'] ?? "No Body";
  //
  //   /// Android notification config
  //   AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
  //     'CHANNEL_ID', //must be unique
  //     'CHANNEL_NAME',
  //     channelDescription: "Notification channel for basic test",
  //     priority: Priority.high,
  //     importance: Importance.high,
  //   );
  //
  //   ///IOS notification config
  //   DarwinNotificationDetails iosDetails = const DarwinNotificationDetails(
  //     presentAlert: true,
  //     presentBadge: true,
  //     presentSound: true,
  //   );
  //
  //   /// combine platform-specific settings
  //   NotificationDetails notificationDetails = NotificationDetails(
  //     android: androidDetails,
  //     iOS: iosDetails,
  //   );
  //
  //   /// Show notification
  //   await flutterLocalNotificationsPlugin.show(
  //     id: 0,
  //     title: title,
  //     body: body,
  //     notificationDetails: notificationDetails,
  //   );
  // }

  ///Initializing the local notification system (both android and ios)
  static Future<void> _initializeLocalNotification() async {
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings("@drawable/notification_icon");

    const DarwinInitializationSettings iosInit = DarwinInitializationSettings();
    final InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        log("User tapped notification: ${response.payload}");
      },
    );
  }

  /// Handle notification tap when app in terminated
  static Future<void> _getInitialNotification() async {
    RemoteMessage? message = await FirebaseMessaging.instance
        .getInitialMessage();

    if (message != null) {
      log(
        "App launched from terminated state via notification: ${message.data}",
      );
    }
  }
}

import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  //firebase messaging
  // void firebaseMessaging() async {
  //   FirebaseMessaging messaging = FirebaseMessaging.instance;
  //   String? token = await messaging.getToken();
  //   log("======FCM=====token $token");
  //
  //   //foreground message
  //   FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  //     final title = message.notification?.title ?? "N/A";
  //     final body = message.notification?.body ?? "N/A";
  //     showDialog(
  //       context: context,
  //       builder: (context) {
  //         return AlertDialog(
  //           title: Text(title),
  //           content: Text(
  //             maxLines: 1,
  //             body,
  //             style: TextStyle(overflow: TextOverflow.ellipsis),
  //           ),
  //           actions: [
  //             TextButton(
  //               onPressed: () {
  //                 Navigator.push(
  //                   context,
  //                   MaterialPageRoute(
  //                     builder: (context) =>
  //                         NotificationDetailsScreen(title: title, body: body),
  //                   ),
  //                 );
  //               },
  //               child: Text("Details"),
  //             ),
  //             TextButton(
  //               onPressed: () {
  //                 Navigator.pop(context);
  //               },
  //               child: Text("Cancel"),
  //             ),
  //           ],
  //         );
  //       },
  //     );
  //   });
  //
  //   // app is not close but is in background
  //   FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
  //     final title = message.notification?.title ?? "N/A";
  //     final body = message.notification?.body ?? "N/A";
  //     Navigator.push(
  //       context,
  //       MaterialPageRoute(
  //         builder: (c) => NotificationDetailsScreen(title: title, body: body),
  //       ),
  //     );
  //   });
  //
  //   // App is fully close / app is in terminated state
  //   messaging.getInitialMessage().then((message) {
  //     if (message != null) {
  //       final title = message.notification?.title ?? "";
  //       final body = message.notification?.body ?? "";
  //       Navigator.push(
  //         context,
  //         MaterialPageRoute(
  //           builder: (c) => NotificationDetailsScreen(title: title, body: body),
  //         ),
  //       );
  //     }
  //   });
  // }
  //

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        centerTitle: true,
        title: Text(
          "Flutter push notification",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Center(
        // child: ElevatedButton(
        //   onPressed: () {
        //     firebaseMessaging();
        //   },
        //   child: Text("Send"),
        // ),
      ),
    );
  }
}

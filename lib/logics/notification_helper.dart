import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:privacy_of_animal/logics/home/home.dart';
import 'package:privacy_of_animal/utils/service_locator.dart';
import 'package:privacy_of_animal/utils/stream_navigator.dart';

class NotificationHelper {
  FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;
  BuildContext _context;

  // Notification 세팅/초기화
  void initializeNotification(BuildContext context) {
    var initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    var initializationSettingsiOS =IOSInitializationSettings();

    var initializationSettings =InitializationSettings(
      initializationSettingsAndroid, initializationSettingsiOS
    );

    this._context = context;

    _flutterLocalNotificationsPlugin =FlutterLocalNotificationsPlugin();
    _flutterLocalNotificationsPlugin.initialize(initializationSettings,
      onSelectNotification: _onSelectNotification);
  }

  // Notification 눌렀을 때 나오는 메시지
  Future<void> _onSelectNotification(String payload) async {
    showDialog(
      context: _context,
      builder: (context) {
        StreamNavigator.pop(context);
        sl.get<HomeBloc>().emitEvent(HomeEventNavigate(index: 2));
        return Container();
      }
    );
  }

  Future<void> showChatNotification(String nickName, String content) async {
    var android =AndroidNotificationDetails(
      'Chat Notification ID',
      'Chat Notification NAME',
      'Chat Notification',
      priority: Priority.High, importance: Importance.Max
    );
    var iOS =IOSNotificationDetails();
    var platform =NotificationDetails(android,iOS);

    await _flutterLocalNotificationsPlugin.show(
      0, nickName,content,platform,
      payload: '채팅'
    );
  }

  // 상대방이 친구신청을 수락했을 시 알림
  Future<void> showFriendsNotification(String nickName) async {
    var android =AndroidNotificationDetails(
      'Friends Notification ID',
      'Friends Notification NAME',
      'Friends Notification',
      priority: Priority.High, importance: Importance.Max
    );
    var iOS =IOSNotificationDetails();
    var platform =NotificationDetails(android,iOS);

    await _flutterLocalNotificationsPlugin.show(
      0, '친구','$nickName 님이 친구신청을 수락하였습니다.',platform,
      payload: '친구'
    );
  }

  // 상대방이 친구 신청 보냈을 시 알림
  Future<void> showRequestNotification(String nickName) async {
    var android =AndroidNotificationDetails(
      'FriendsRequest Notification ID',
      'FriendsRequest Notification NAME',
      'FriendsRequest Notification',
      priority: Priority.High, importance: Importance.Max
    );
    var iOS =IOSNotificationDetails();
    var platform =NotificationDetails(android,iOS);

    await _flutterLocalNotificationsPlugin.show(
      0, '친구 신청','$nickName 님으로부터 친구신청이 왔습니다.',platform,
      payload: '친구 신청 알림'
    );
  }
}
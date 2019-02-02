import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rflutter_alert/rflutter_alert.dart';

class BackButtonAction {
  static DateTime currentBackPressTime;

  static Future<bool> oneMorePressToExit(BuildContext context, ScaffoldState state) {
    DateTime now = DateTime.now();
    if(now.difference(currentBackPressTime) > Duration(seconds: 1)){
      currentBackPressTime = now;
      state.showSnackBar(SnackBar(content: Text('한번 더 누르시면 종료됩니다.'),duration: const Duration(milliseconds: 300)));
      return Future.value(false);
    }
    return Future.value(true);
  }

  static Future<bool> stopInMiddle(BuildContext context) async{
    Alert(
      title: '중단하시겠습니까?',
      type: AlertType.warning,
      context: context,
      content: Text(
        '자동으로 로그아웃 됩니다.'
      ),
      buttons: [
        DialogButton(
          child: Text(
            '예',
            style: TextStyle(
              color: Colors.white
            ),
          ),
          onPressed: () => SystemChannels.platform.invokeMethod('SystemNavigator.pop'),
        ),
        DialogButton(
          child: Text(
            '아니오',
            style: TextStyle(
              color: Colors.white
            ),
          ),
          onPressed: () => Navigator.of(context).pop()
        )
      ]
    ).show();
    return Future.value(false);
  }
}
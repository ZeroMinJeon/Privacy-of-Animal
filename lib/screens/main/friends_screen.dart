import 'package:flutter/material.dart';
import 'package:privacy_of_animal/bloc_helpers/bloc_event_state_builder.dart';
import 'package:privacy_of_animal/logics/current_user.dart';
import 'package:privacy_of_animal/logics/friends/friends.dart';
import 'package:privacy_of_animal/resources/colors.dart';
import 'package:privacy_of_animal/screens/sub/friends_list.dart';
import 'package:privacy_of_animal/screens/sub/friends_request_list.dart';
import 'package:privacy_of_animal/utils/service_locator.dart';
import 'package:privacy_of_animal/utils/stream_snackbar.dart';

class FriendsScreen extends StatefulWidget {
  @override
  _FriendsScreenState createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with SingleTickerProviderStateMixin{

  final FriendsBloc friendsBloc = sl.get<FriendsBloc>();
  TabController tabController;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    tabController.dispose();
    sl.get<CurrentUser>().newFriendsNum = 0;
    super.dispose();
  }

  

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0.0,
          backgroundColor: primaryBlue,
          actions: [
            BlocBuilder(
              bloc: friendsBloc,
              builder: (context, FriendsState state){
                if(state.isFriendsNotificationToggleFailed) {
                  streamSnackbar(context, '알림 설정에 실패하였습니다.');
                  friendsBloc.emitEvent(FriendsEventStateClear());
                }
                return IconButton(
                  icon: Icon(sl.get<CurrentUser>().friendsNotification
                    ? Icons.notifications
                    : Icons.notifications_off),
                  onPressed: () => friendsBloc.emitEvent(FriendsEventFriendsNotification())
                );
              }
            )
          ],
          bottom: TabBar(
            tabs: [
              Tab(child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('친구'),
                  SizedBox(width: 10.0),
                  BlocBuilder(
                    bloc: friendsBloc,
                    builder: (context, FriendsState state){
                      int newFriendsNum = sl.get<CurrentUser>().newFriendsNum;
                      if(newFriendsNum==0) {
                        return Container();
                      }
                      return Container(
                        padding: EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle
                        ),
                        child: Text(sl.get<CurrentUser>().newFriendsNum.toString())
                      );
                    }
                  )
                ],
              )),
              Tab(child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('친구신청'),
                  SizedBox(width: 10.0),
                  BlocBuilder(
                    bloc: friendsBloc,
                    builder: (context, FriendsState state){
                      int requestNum = sl.get<CurrentUser>().friendsRequestList.length;
                      if(requestNum==0) {
                        return Container();
                      }
                      return Container(
                        padding: EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle
                        ),
                        child: Text(sl.get<CurrentUser>().friendsRequestList.length.toString())
                      );
                    },
                  )
                ],
              ))
            ],
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            labelStyle: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20.0
            ),
            unselectedLabelColor: Colors.white.withOpacity(0.2),
            controller: tabController,
          ),
        ),
        body: TabBarView(
          children: [
            FriendsList(friendsBloc: friendsBloc),
            FriendsRequestList(friendsBloc: friendsBloc)
          ],
          controller: tabController,
        ),
      ),
    );
  }
}
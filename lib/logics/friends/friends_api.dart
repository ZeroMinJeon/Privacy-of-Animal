import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meta/meta.dart';
import 'package:privacy_of_animal/logics/current_user.dart';
import 'package:privacy_of_animal/logics/database_helper.dart';
import 'package:privacy_of_animal/logics/firebase_api.dart';
import 'package:privacy_of_animal/models/chat_list_model.dart';
import 'package:privacy_of_animal/models/user_model.dart';
import 'package:privacy_of_animal/utils/service_locator.dart';
import 'package:privacy_of_animal/resources/strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FriendsAPI {

  String uid;
  
  FriendsAPI() {uid = uid;}

  /// [친구 알림 설정]
  Future<void> setFriendsNotification() async {
    SharedPreferences prefs = await sl.get<DatabaseHelper>().sharedPreferences;
    bool value = !sl.get<CurrentUser>().friendsNotification;
    prefs.setBool(uid+friendsNotification, value);
    sl.get<CurrentUser>().friendsNotification = value;
  }

  /// [새로운 친구수 갱신]
  void updateNewFriends(int newFriendsNum) {
    sl.get<CurrentUser>().newFriendsNum = newFriendsNum;
  }

  /// [친구목록] 및 [친구신청 목록] 가져오기
  Future<void> fetchFriendsList(List<dynamic> friends, {@required bool isFriendsList}) async {
    List<UserModel> userList = List<UserModel>();
    if(friends.isNotEmpty) {
      for(var user in friends) {
        DocumentSnapshot userInfo = await sl.get<FirebaseAPI>().getFirestore()
          .collection(firestoreUsersCollection)
          .document((user as DocumentSnapshot).documentID).get();
        userList.add(UserModel.fromSnapshot(snapshot: userInfo));
      }
    }
    if(isFriendsList) {
      sl.get<CurrentUser>().friendsList = userList;
    } else {
      sl.get<CurrentUser>().friendsRequestList = userList;
    }
  }

  /// [서버에서 친구 차단]
  Future<void> blockFriendsForServer(UserModel userToBlock) async {
    String currentUser = uid;

    DocumentReference myselfDoc = sl.get<FirebaseAPI>().getFirestore()
      .collection(firestoreUsersCollection)
      .document(currentUser)
      .collection(firestoreFriendsSubCollection)
      .document(userToBlock.uid);

    DocumentReference userToBlockDoc = sl.get<FirebaseAPI>().getFirestore()
      .collection(firestoreUsersCollection)
      .document(userToBlock.uid)
      .collection(firestoreFriendsSubCollection)
      .document(currentUser);

    print(myselfDoc.documentID + '\n' + userToBlockDoc.documentID);

    QuerySnapshot chatRoomSnapshot = await sl.get<FirebaseAPI>().getFirestore()
      .collection(firestoreFriendsMessageCollection)
      .where('$firestoreChatUsersField.$currentUser', isEqualTo: true)
      .where('$firestoreChatUsersField.${userToBlock.uid}', isEqualTo: true)
      .getDocuments();

    WriteBatch batch = sl.get<FirebaseAPI>().getFirestore().batch();

    if(chatRoomSnapshot.documents.isNotEmpty) {
      DocumentReference realChatRoom =chatRoomSnapshot.documents[0].reference;

      QuerySnapshot chatSnapshot = await realChatRoom
      .collection(realChatRoom.documentID)
      .getDocuments();

      for(DocumentSnapshot chat in chatSnapshot.documents) {
        batch.delete(chat.reference);
      }
      batch.delete(realChatRoom);
    }

    batch.delete(myselfDoc);
    batch.delete(userToBlockDoc);
    await batch.commit();
  }

  /// [로컬에서 친구 차단]
  void blockFriendsForLocal(UserModel userToBlock) {
    sl.get<CurrentUser>().friendsList.remove(userToBlock);
    sl.get<CurrentUser>().chatHistory.remove(userToBlock.uid);
    sl.get<CurrentUser>().chatListHistory.remove(userToBlock.uid);
    sl.get<CurrentUser>().chatRoomNotification.remove(userToBlock.uid);
    sl.get<CurrentUser>().newFriendsNum = 0;
  }

  /// [서버에서 친구신청 수락]
  Future<void> acceptFriendsForServer(UserModel requestingUser) async {

    String currentUser = uid;

    DocumentReference myselfDoc = sl.get<FirebaseAPI>().getFirestore()
      .collection(firestoreUsersCollection)
      .document(currentUser)
      .collection(firestoreFriendsSubCollection)
      .document(requestingUser.uid);

    DocumentReference requestingUserDoc = sl.get<FirebaseAPI>().getFirestore()
      .collection(firestoreUsersCollection)
      .document(requestingUser.uid)
      .collection(firestoreFriendsSubCollection)
      .document(currentUser);

    DocumentReference chatDoc = sl.get<FirebaseAPI>().getFirestore()
      .collection(firestoreFriendsMessageCollection)
      .document();
    
    WriteBatch batch = sl.get<FirebaseAPI>().getFirestore().batch();

    batch.setData(myselfDoc, {firestoreFriendsField: true},merge: true);
    batch.setData(requestingUserDoc, {
      firestoreFriendsField: true,
      firestoreFriendsAccepted: true,
      firestoreFriendsUID: currentUser
    });

    batch.setData(chatDoc, {
      firestoreChatOutField: {
        currentUser: Timestamp(0,0),
        requestingUser.uid: Timestamp(0,0)
      },
      firestoreChatDeleteField: {
        currentUser: false,
        requestingUser.uid: false
      },
      firestoreChatUsersField: {
        currentUser: true,
        requestingUser.uid: true
      }
    });

    await batch.commit();
  }

  /// [로컬에서 친구신청 수락]
  void acceptFriendsForLocal(UserModel requestingUser) {
    sl.get<CurrentUser>().friendsRequestList.remove(requestingUser);
    sl.get<CurrentUser>().chatHistory[requestingUser.uid] = [];
    sl.get<CurrentUser>().chatListHistory[requestingUser.uid] = ChatListModel();
    sl.get<CurrentUser>().chatRoomNotification[requestingUser.uid] = true;
  } 

  /// [서버에서 친구신청 삭제]
  Future<void> rejectFriendsForServer(UserModel userToReject) async {
    DocumentReference doc = sl.get<FirebaseAPI>().getFirestore()
      .collection(firestoreUsersCollection)
      .document(uid)
      .collection(firestoreFriendsSubCollection)
      .document(userToReject.uid);
    await sl.get<FirebaseAPI>().getFirestore().runTransaction((tx) async{
      await tx.delete(doc);
    });
  }

  /// [로컬에서 친구신청 삭제]
  void rejectFriendsForLocal(UserModel userToReject) {
    sl.get<CurrentUser>().friendsRequestList.remove(userToReject);
  }

  /// [친구와 대화]
  Future<String> chatWithFriends(String userToChat) async {
    String currentUser = uid;

    QuerySnapshot snapshot = await sl.get<FirebaseAPI>().getFirestore()
      .collection(firestoreFriendsMessageCollection)
      .where('$firestoreChatUsersField.$currentUser',isEqualTo: true)
      .where('$firestoreChatUsersField.$userToChat',isEqualTo: true)
      .getDocuments();

    String chatRoomID = snapshot.documents[0].documentID;
    sl.get<CurrentUser>().chatRoomNotification[chatRoomID] = true;
    sl.get<CurrentUser>().chatHistory[userToChat] = [];

    return snapshot.documents[0].documentID;
  }
}
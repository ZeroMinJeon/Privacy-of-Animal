import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:privacy_of_animal/logics/current_user.dart';
import 'package:privacy_of_animal/logics/database_helper.dart';
import 'package:privacy_of_animal/logics/firebase_api.dart';
import 'package:privacy_of_animal/logics/notification_helper.dart';
import 'package:privacy_of_animal/logics/other_profile/other_profile.dart';
import 'package:privacy_of_animal/logics/same_match/same_match.dart';
import 'package:privacy_of_animal/models/chat_list_model.dart';
import 'package:privacy_of_animal/models/user_model.dart';
import 'package:privacy_of_animal/utils/service_locator.dart';
import 'package:privacy_of_animal/resources/strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FriendsAPI {

  String _uid;
  UserModel _notifyingFriends, _notifyingRequestFrom;
  
  FriendsAPI() {
    _uid = sl.get<CurrentUser>().uid;
    assert(_uid!=null, '사용자 UID 초기화 실패');
  } 

  /// [친구 알림 설정]
  Future<void> setFriendsNotification() async {
    SharedPreferences prefs = await sl.get<DatabaseHelper>().sharedPreferences;
    bool value = !sl.get<CurrentUser>().friendsNotification;
    prefs.setBool(_uid+friendsNotification, value);
    sl.get<CurrentUser>().friendsNotification = value;
  }

  /// [친구 증가]
  Future<void> fetchIncreasedFriends(List<DocumentChange> newFriendsList) async {
    for(DocumentChange newFriends in newFriendsList) {
      DocumentSnapshot newFriendsSnapshot = await sl.get<FirebaseAPI>().getFirestore()
        .collection(firestoreUsersCollection)
        .document(newFriends.document.documentID)
        .get();
      UserModel newFriendsUserModel =UserModel.fromSnapshot(snapshot: newFriendsSnapshot);
      sl.get<CurrentUser>().friendsList.add(newFriendsUserModel);
      _updateOtherProfileFriends(newFriendsUserModel.uid);
      _notifyingFriends ??=newFriendsUserModel;
    }
  }

  void _updateOtherProfileFriends(String otherUserUID) {
    if(otherUserUID == sl.get<CurrentUser>().currentProfileUID) {
      sl.get<SameMatchBloc>().emitEvent(SameMatchEventRefreshFriends());
      sl.get<OtherProfileBloc>().emitEvent(OtherProfileEventRefreshFriends());
    }
  }

  void notifyNewFriends() {
    if(sl.get<CurrentUser>().uid!=_notifyingFriends.uid &&
       sl.get<CurrentUser>().friendsNotification) {
      sl.get<NotificationHelper>().showFriendsNotification(_notifyingFriends.fakeProfileModel.nickName);
    }
  }

  /// [친구 감소]
  Future<void> fetchDecreasedFriends(List<DocumentChange> deletedFriendsList) async {
    for(DocumentChange deletedFriends in deletedFriendsList) {
      String deletedFriendsUID = deletedFriends.document.documentID;
      sl.get<CurrentUser>().friendsList.removeWhere((friendsModel) => friendsModel.uid==deletedFriendsUID);
      _updateOtherProfileFriends(deletedFriendsUID);
    }
  }

  /// [받은 친구신청 증가]
  Future<void> fetchIncreasedRequestFrom(List<DocumentChange> newRequestFromList) async {
    for(DocumentChange newRequestFrom in newRequestFromList) {
      DocumentSnapshot newRequestFromSnapshot = await sl.get<FirebaseAPI>().getFirestore()
        .collection(firestoreUsersCollection)
        .document(newRequestFrom.document.documentID)
        .get();
      UserModel newRequestFromUserModel =UserModel.fromSnapshot(snapshot: newRequestFromSnapshot);
      sl.get<CurrentUser>().requestFromList.add(newRequestFromUserModel);
      _updateOtherProfileRequest(newRequestFromUserModel.uid);
      _notifyingRequestFrom ??= newRequestFromUserModel;
    }
  }

  void _updateOtherProfileRequest(String otherUserUID) {
    if(otherUserUID == sl.get<CurrentUser>().currentProfileUID) {
      sl.get<SameMatchBloc>().emitEvent(SameMatchEventRefreshRequestFrom());
      sl.get<OtherProfileBloc>().emitEvent(OtherProfileEventRefreshRequestFrom());
    }
  }

  void notifyNewRequestFrom() {
    if(sl.get<CurrentUser>().friendsNotification) {
      sl.get<NotificationHelper>().showRequestNotification(_notifyingRequestFrom.fakeProfileModel.nickName);
    }
  }

  /// [친구신청 감소]
  Future<void> fetchDecreasedRequestFrom(List<DocumentChange> deletedRequestFromList) async {
    for(DocumentChange deletedRequestFrom in deletedRequestFromList) {
      String deletedRequestFromUID = deletedRequestFrom.document.documentID;
      sl.get<CurrentUser>().requestFromList.removeWhere((requestFromModel) => requestFromModel.uid==deletedRequestFromUID);
      _updateOtherProfileRequest(deletedRequestFromUID);
    }
  }


  /// [서버에서 친구 차단]
  Future<void> blockFriendsForServer(UserModel userToBlock) async {

    DocumentReference myselfDoc = sl.get<FirebaseAPI>().getFirestore()
      .collection(firestoreUsersCollection)
      .document(_uid)
      .collection(firestoreFriendsSubCollection)
      .document(userToBlock.uid);

    DocumentReference userToBlockDoc = sl.get<FirebaseAPI>().getFirestore()
      .collection(firestoreUsersCollection)
      .document(userToBlock.uid)
      .collection(firestoreFriendsSubCollection)
      .document(_uid);
      
    QuerySnapshot chatRoomSnapshot = await sl.get<FirebaseAPI>().getFirestore()
      .collection(firestoreFriendsMessageCollection)
      .where('$firestoreChatUsersField.$_uid', isEqualTo: true)
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
  }

  /// [서버에서 친구신청 수락]
  Future<void> acceptFriendsForServer(UserModel requestFromingUser) async {

    String currentUser = _uid;

    DocumentReference myselfDoc = sl.get<FirebaseAPI>().getFirestore()
      .collection(firestoreUsersCollection)
      .document(currentUser)
      .collection(firestoreFriendsSubCollection)
      .document(requestFromingUser.uid);

    DocumentReference requestFromingUserDoc = sl.get<FirebaseAPI>().getFirestore()
      .collection(firestoreUsersCollection)
      .document(requestFromingUser.uid)
      .collection(firestoreFriendsSubCollection)
      .document(currentUser);

    DocumentReference chatDoc = sl.get<FirebaseAPI>().getFirestore()
      .collection(firestoreFriendsMessageCollection)
      .document();
    
    WriteBatch batch = sl.get<FirebaseAPI>().getFirestore().batch();

    batch.setData(myselfDoc, {firestoreFriendsField: true},merge: true);
    batch.setData(requestFromingUserDoc, {
      firestoreFriendsField: true,
      firestoreFriendsAccepted: true,
      firestoreFriendsUID: currentUser
    });

    batch.setData(chatDoc, {
      firestoreChatOutField: {
        currentUser: Timestamp(0,0),
        requestFromingUser.uid: Timestamp(0,0)
      },
      firestoreChatDeleteField: {
        currentUser: false,
        requestFromingUser.uid: false
      },
      firestoreChatUsersField: {
        currentUser: true,
        requestFromingUser.uid: true
      }
    });

    await batch.commit();
  }

  /// [로컬에서 친구신청 수락]
  Future<void> acceptFriendsForLocal(UserModel requestFromingUser) async{
    SharedPreferences prefs = await sl.get<DatabaseHelper>().sharedPreferences;
    prefs.setBool(requestFromingUser.uid+chatNotification, true);

    sl.get<CurrentUser>().requestFromList.remove(requestFromingUser);
    sl.get<CurrentUser>().chatHistory[requestFromingUser.uid] = [];
    sl.get<CurrentUser>().chatListHistory[requestFromingUser.uid] = ChatListModel();
    sl.get<CurrentUser>().chatRoomNotification[requestFromingUser.uid] = true;
  } 

  /// [서버에서 친구신청 삭제]
  Future<void> rejectFriendsForServer(UserModel userToReject) async {
    DocumentReference doc = sl.get<FirebaseAPI>().getFirestore()
      .collection(firestoreUsersCollection)
      .document(_uid)
      .collection(firestoreFriendsSubCollection)
      .document(userToReject.uid);
    await sl.get<FirebaseAPI>().getFirestore().runTransaction((tx) async{
      await tx.delete(doc);
    });
  }

  /// [로컬에서 친구신청 삭제]
  void rejectFriendsForLocal(UserModel userToReject) {
    sl.get<CurrentUser>().requestFromList.remove(userToReject);
  }

  /// [친구와 대화]
  Future<String> chatWithFriends(String userToChat) async {
    String currentUser = _uid;

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
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:privacy_of_animal/bloc_helpers/bloc_event_state_builder.dart';
import 'package:privacy_of_animal/logics/current_user.dart';
import 'package:privacy_of_animal/logics/firebase_api.dart';
import 'package:privacy_of_animal/logics/random_chat/random_chat.dart';
import 'package:privacy_of_animal/logics/random_loading/random_loading.dart';
import 'package:privacy_of_animal/resources/colors.dart';
import 'package:privacy_of_animal/screens/main/other_profile_screen.dart';
import 'package:privacy_of_animal/utils/back_button_dialog.dart';
import 'package:privacy_of_animal/utils/service_locator.dart';
import 'package:privacy_of_animal/widgets/progress_indicator.dart';
import 'package:privacy_of_animal/resources/strings.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class RandomChatScreen extends StatefulWidget {

  final String chatRoomID;
  final DocumentSnapshot receiver;

  RandomChatScreen({@required this.chatRoomID,@required this.receiver});

  @override
  _RandomChatScreenState createState() => _RandomChatScreenState();
}

class _RandomChatScreenState extends State<RandomChatScreen> {

  final ScrollController scrollController = ScrollController();
  final TextEditingController messageController = TextEditingController();
  final FocusNode messageFocusNode = FocusNode();

  final RandomChatBloc randomChatBloc = sl.get<RandomChatBloc>();
  final RandomLoadingBloc randomLoadingBloc = sl.get<RandomLoadingBloc>();

  // Cloud Firestore에서 불러와서 저장.
  List<DocumentSnapshot> messages = List<DocumentSnapshot>();
  bool isReceiverOut = false;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting();
    randomChatBloc.emitEvent(RandomChatEventStateClear());
  }

  @override
  void dispose() {
    super.dispose();
    messageController.dispose();
    messageFocusNode.dispose();
    scrollController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '채팅',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold
          ),
        ),
        centerTitle: true,
        elevation: 0.0,
        backgroundColor: primaryBlue,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              randomChatBloc.emitEvent(RandomChatEventOut(chatRoomID: widget.chatRoomID));
              randomLoadingBloc.emitEvent(RandomLoadingEventMatchStart());
              Navigator.pushReplacementNamed(context, routeRandomLoading);
            },
          )
        ],
      ),
      body: WillPopScope(
        onWillPop: () { 
          if(isReceiverOut) {
            randomChatBloc.emitEvent(RandomChatEventOut(chatRoomID: widget.chatRoomID));
            return Future.value(true);
          } else {
            return BackButtonAction.dialogChatExit(context, widget.chatRoomID);
          }
        },
        child: Column(
          children: <Widget>[
            Container(
              padding: EdgeInsets.only(top: 10.0),
              child: Text('낯선 상대와 연결되었습니다.'),
            ),
            Flexible(
              child: StreamBuilder(
                stream: sl.get<FirebaseAPI>().getFirestore()
                  .collection(firestoreRandomMessageCollection)
                  .document(widget.chatRoomID)
                  .collection(widget.chatRoomID)
                  .orderBy(firestoreChatTimestampField,descending: true)
                  .snapshots(),
                builder: (context, snapshot){
                  if(!snapshot.hasData){
                    return CustomProgressIndicator();
                  } else {
                    messages = snapshot.data.documents;
                    return ListView.builder(
                      padding: EdgeInsets.all(10.0),
                      itemBuilder: (context,index) => _buildMessage(index,snapshot.data.documents[index]),
                      itemCount: snapshot.data.documents.length,
                      reverse: true,
                      controller: scrollController,
                    );
                  }
                }
              ),
            ),
            StreamBuilder(
              stream: sl.get<FirebaseAPI>().getFirestore()
                  .collection(firestoreRandomMessageCollection)
                  .document(widget.chatRoomID)
                  .snapshots(),
              builder: (context, snapshot){
                if(snapshot.hasData && snapshot.data.data!=null && snapshot.data.data[firestoreChatOutField]){
                  randomChatBloc.emitEvent(RandomChatEventFinished());
                  isReceiverOut = true;
                  return Text('상대방이 나갔습니다.');
                }
                return Container();
              },
            ),
            BlocBuilder(
              bloc: randomChatBloc,
              builder: (context, RandomChatState state){
                if(state.isChatFinished){
                  return Container(padding: const EdgeInsets.only(bottom: 10.0),);
                }
                return Row(
                  children: <Widget>[
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.all(10.0),
                        child: TextField(
                          style: TextStyle(color: primaryGreen, fontSize: 15.0),
                          decoration: InputDecoration.collapsed(
                            hintText: '메시지를 입력하세요.',
                            hintStyle: TextStyle(color: Colors.grey)
                          ),
                          controller: messageController,
                          focusNode: messageFocusNode,
                        ),
                      ),
                    ),
                    Material(
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: 8.0),
                        child: IconButton(
                          icon: Icon(Icons.send),
                          onPressed: () {
                            randomChatBloc.emitEvent(
                              RandomChatEventMessageSend(
                                content: messageController.text,
                                receiver: widget.receiver.documentID,
                                chatRoomID: widget.chatRoomID
                              ));
                              messageController.clear();
                            },
                          color: Colors.black,
                        ),
                      ),
                    )
                  ],
                ); 
              }
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(int index, DocumentSnapshot document) {
    // 내가 보내는 메시지
    if(document[firestoreChatFromField] == sl.get<CurrentUser>().uid){
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          _isLastRight(index) ?
          Container(
            margin: EdgeInsets.only(right: 10.0),
            child: Text(
              DateFormat('kk:mm','ko')
                .format(DateTime.fromMillisecondsSinceEpoch(
                  (document[firestoreChatTimestampField] as Timestamp).millisecondsSinceEpoch)),
                style: TextStyle(color: Colors.grey,fontSize: 12.0),
            ),
          ) : Container(),
          Container(
            child: Text(
              document[firestoreChatContentField],
              style: TextStyle(
                color: Colors.black
              ),
            ),
            padding: EdgeInsets.fromLTRB(15.0,10.0,15.0,10.0),
            decoration: BoxDecoration(
              color: primaryBeige,
              borderRadius: BorderRadius.circular(3.0)
            ),
            margin: EdgeInsets.only(bottom: 10.0, right: 10.0),
          ),
        ],
      );
      // 상대방이 보내는 메시지
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          Column(
            children: <Widget>[
              GestureDetector(
                child: CircleAvatar(
                  backgroundImage: _isFirstLeft(index)
                  ? AssetImage(widget.receiver.data[firestoreFakeProfileField][firestoreAnimalImageField])
                  : null,
                  backgroundColor: Colors.transparent,
                ),
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (context) => OtherProfileScreen(user: widget.receiver)
                )),
              ),
              Text(
                _isFirstLeft(index) ? 
                widget.receiver.data[firestoreFakeProfileField][firestoreNickNameField]
                :''
              )
            ],
          ),
          Container(
            child: Text(
              document[firestoreChatContentField],
              style: TextStyle(color: Colors.black),
            ),
            padding: EdgeInsets.fromLTRB(15.0,10.0,15.0,10.0),
            decoration: BoxDecoration(
              color: primaryBeige,
              borderRadius: BorderRadius.circular(8.0)
            ),
            margin: EdgeInsets.only(left: 10.0)
          ),
          _isLastLeft(index) ?
          Container(
            margin: EdgeInsets.only(left: 10.0,top: 15.0),
            child: Text(
              DateFormat('kk:mm','ko')
                .format(DateTime.fromMillisecondsSinceEpoch(
                  (document[firestoreChatTimestampField] as Timestamp).millisecondsSinceEpoch)),
                style: TextStyle(color: Colors.grey,fontSize: 12.0),
            ),
          ) : Container()
        ],
      );
    }
  }

  bool _isFirstLeft(int index) {
    if((index<messages.length-1 && messages!=null && messages[index+1][firestoreChatFromField] 
      != messages[index][firestoreChatFromField])
     || index == messages.length-1) {
       return true;
     } else {
       return false;
     }
  }

  bool _isLastLeft(int index) {
    if((index>0 && messages!=null && messages[index-1][firestoreChatFromField] == sl.get<CurrentUser>().uid) 
      || index==0){
        return true;
    } else {
      return false;
    }
  }

  bool _isLastRight(int index) {
    if((index>0 && messages!=null && messages[index-1][firestoreChatToField] == sl.get<CurrentUser>().uid) 
      || index==0){
        return true;
    } else {
      return false;
    }
  }
}
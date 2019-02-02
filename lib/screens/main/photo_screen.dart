import 'package:flutter/material.dart';
import 'package:privacy_of_animal/logics/photo/photo.dart';
import 'package:privacy_of_animal/resources/resources.dart';
import 'package:privacy_of_animal/bloc_helpers/bloc_helpers.dart';
import 'package:privacy_of_animal/utils/service_locator.dart';
import 'dart:io';

import 'package:privacy_of_animal/widgets/primary_button.dart';


class PhotoScreen extends StatefulWidget {
  @override
  _PhotoScreenState createState() => _PhotoScreenState();
}

class _PhotoScreenState extends State<PhotoScreen> {
  final PhotoBloc _photoBloc = sl.get<PhotoBloc>();
  
  @override
  Widget build(BuildContext context){
    return Scaffold(
      body: Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: BlocBuilder(
                    bloc: _photoBloc,
                    builder: (context, PhotoState state){
                      if(state.takedPhoto) {
                        return Container(
                          height: ScreenUtil.height/1.2,
                          width: ScreenUtil.width/1.2,
                          child: FittedBox(
                            fit:BoxFit.contain,
                            child: Image.file(File(state.path))
                          )
                        );
                      }
                      return Center(child: Text('사진을 찍지 않았습니다.')
                      );
                    }
                  )
                ),
                SizedBox(height: ScreenUtil.height/18),
                RaisedButton(
                  padding: EdgeInsets.symmetric(horizontal: ScreenUtil.width/3, vertical: ScreenUtil.height/40),
                  color: primaryPink,
                  child: Text(
                    '사진 찍기',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 17.0
                    ),
                  ),
                  onPressed: () => _photoBloc.emitEvent(PhotoEventTaking()),
                ),
                SizedBox(height: 20.0),
                BlocBuilder(
                  bloc: _photoBloc,
                  builder: (context, PhotoState state){
                    return RaisedButton(
                      padding: EdgeInsets.symmetric(horizontal: ScreenUtil.width/3, vertical: ScreenUtil.height/40),
                      color: state.takedPhoto ? primaryPink : Colors.grey,
                      child: Text(
                        '분석 하기',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 17.0
                        ),
                      ),
                      onPressed: () => state.takedPhoto ? _photoBloc.emitEvent(PhotoEventTaking()) : null
                    );
                  }
                ),
                Container(
                  padding: const EdgeInsets.only(top: 10.0,right: 30.0),
                  child: Text(
                    photoWarningMessage1+'\n'+photoWarningMessage2,
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold
                    ),
                  ),
                )
              ],
            ),
          ),
      ),
    );
  }
}

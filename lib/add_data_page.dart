import 'dart:io';
import 'dart:ui';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as m;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:esys_flutter_share/esys_flutter_share.dart'
    as esys_flutter_share;
import 'package:share_extend/share_extend.dart';
import 'common_util.dart';

import 'excel_mgr.dart';
import 'add_detail_data_page.dart';
import 'add_expenditure_data_page.dart';

class AddDataPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _AddDataPageState();
  }
}

class _AddDataPageState extends State<AddDataPage> {
  double _width = MediaQueryData.fromWindow(window).size.width;
  double _height = MediaQueryData.fromWindow(window).size.height;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
//      appBar: AppBar(title: Center(child: Text("分享"))),
      body: Builder(builder: (BuildContext context) {
        return _buildBody();
      }),
    );
  }

  Widget _buildBody() {
    return Column(
//      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        SizedBox(height: _width * 10 / 100),
        Divider(),
        _buildAddDetailDataButton(),
        Divider(),
        _buildAddExpenditureDataButton(),
        Divider(),
      ],
    );
  }

  Widget _buildAddDetailDataButton() {
    return RaisedButton(
      child: FittedBox(child: Text("添加随喜记录")),
      onPressed: () {
        Navigator.of(context).push(MaterialPageRoute(builder: (context) {
          return Scaffold(
            appBar: AppBar(title: Text('添加随喜记录')),
            body: AddDetailDataPage(),
          );
        }));
      },
    );
  }

  Widget _buildAddExpenditureDataButton() {
    return RaisedButton(
      child: FittedBox(child: Text("添加支出")),
      onPressed: () {
        Navigator.of(context).push(MaterialPageRoute(builder: (context) {
          return Scaffold(
            appBar: AppBar(title: Text("添加支出")),
            body: AddExpenditureDataPage(),
          );
        }));
      },
    );
  }
}

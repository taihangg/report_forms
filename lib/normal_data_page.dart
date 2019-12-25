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
import 'export_namelist_page.dart';

class NormalDataPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _NormalDataPageState();
  }
}

class _NormalDataPageState extends State<NormalDataPage> {
  _NormalDataPageState() {
    _textStyle = TextStyle(fontSize: _width / 10, color: Colors.black87);
  }

  double _width = MediaQueryData.fromWindow(window).size.width;
  double _height = MediaQueryData.fromWindow(window).size.height;
  TextStyle _textStyle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
//      appBar: AppBar(title: Center(child: Text("分享"))),
      body: Builder(builder: (BuildContext context) {
        return Scrollbar(child: SingleChildScrollView(child: _buildBody()));
      }),
    );
  }

  Widget _buildBody() {
    final sizedBox = SizedBox(height: _width * 10 / 100);
    return Column(
//      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        sizedBox,
        Divider(),
        sizedBox,
        _buildAddDetailDataButton(),
        sizedBox,
        Divider(),
        sizedBox,
        _buildAddExpenditureDataButton(),
        sizedBox,
        Divider(color: Colors.red),
        sizedBox,
        _buildExportNameListTextButton(),
      ],
    );
  }

  Widget _buildAddDetailDataButton() {
    final title = RichText(
        text: TextSpan(children: [
      TextSpan(text: "添加", style: _textStyle),
      TextSpan(
          text: "随喜记录",
          style: TextStyle(fontSize: _width / 10, color: Colors.blueAccent)),
    ]));
    return RaisedButton(
      child: FittedBox(child: title),
      onPressed: () {
        Navigator.of(context).push(MaterialPageRoute(builder: (context) {
          return AddDetailDataPage(title);
        }));
      },
    );
  }

  Widget _buildAddExpenditureDataButton() {
    final title = RichText(
        text: TextSpan(children: [
      TextSpan(text: "添加", style: _textStyle),
      TextSpan(
          text: "支出记录",
          style: TextStyle(fontSize: _width / 10, color: Colors.orange)),
    ]));
    return RaisedButton(
      child: FittedBox(child: title),
      onPressed: () {
        Navigator.of(context).push(MaterialPageRoute(builder: (context) {
          return AddExpenditureDataPage(title);
        }));
      },
    );
  }

  Widget _buildExportNameListTextButton() {
    final title = RichText(
        text: TextSpan(children: [
      TextSpan(text: "导出", style: _textStyle),
      TextSpan(
          text: "名单文件",
          style:
              TextStyle(fontSize: _width / 10, color: Colors.deepPurpleAccent)),
    ]));
    return RaisedButton(
      child: FittedBox(child: title),
      onPressed: () {
        Navigator.of(context).push(MaterialPageRoute(builder: (context) {
          return ExportNameListPage(title);
        }));
      },
    );
  }
}

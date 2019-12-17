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
import 'package:file_picker/file_picker.dart';
import 'common_util.dart';

import 'excel_mgr.dart';
import 'add_detail_data_page.dart';
import 'add_expenditure_data_page.dart';

class OtherPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _OtherPageState();
  }
}

class _OtherPageState extends State<OtherPage> {
  double _width = MediaQueryData.fromWindow(window).size.width;
  double _height = MediaQueryData.fromWindow(window).size.height;

  ExcelMgr _excelMgr = ExcelMgr();

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
        _buildImportDetailDataButton(),
        Divider(),
        _buildImportExpenditureDataButton(),
        Divider(),
        _buildImportDataFileButton(),
        Divider(),
        _buildShareDataFileButton(),
      ],
    );
  }

  Widget _buildImportDetailDataButton() {
    return RaisedButton(
      child: FittedBox(child: Text("从xlsx文件导入随喜数据")),
      onPressed: () {
        assert(false);
        Navigator.of(context).push(MaterialPageRoute(builder: (context) {
          return Scaffold(
            appBar: AppBar(title: Text("从xlsx文件导入随喜数据")),
            body: AddExpenditureDataPage(),
          );
        }));
      },
    );
  }

  Widget _buildImportExpenditureDataButton() {
    return RaisedButton(
      child: FittedBox(child: Text("从xlsx文件导入支出数据")),
      onPressed: () {
        assert(false);
        Navigator.of(context).push(MaterialPageRoute(builder: (context) {
          return Scaffold(
            appBar: AppBar(title: Text("从xlsx文件导入支出数据")),
            body: AddExpenditureDataPage(),
          );
        }));
      },
    );
  }

  Widget _buildImportDataFileButton() {
    return RaisedButton(
      child: FittedBox(child: Text("导入xlsx数据文件")),
      onPressed: () async {
        final File file = await FilePicker.getFile(
            type: FileType.CUSTOM, fileExtension: "xlsx");
        if (null == file) {
          return;
        }
      },
    );
  }

  Widget _buildShareDataFileButton() {
    return RaisedButton(
      child: FittedBox(child: Text("分享数据文件")),
      onPressed: () async {
        String fullPath = _excelMgr.dataFileFullPath;

        await ShareExtend.share(fullPath, "file");
      },
    );
  }
}

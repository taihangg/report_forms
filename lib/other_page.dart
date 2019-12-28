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
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';
import 'common_util.dart';

import 'excel_mgr.dart';
import 'add_detail_data_page.dart';
import 'add_expenditure_data_page.dart';
import 'excel_preview_select_page.dart';

class OtherPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _OtherPageState();
  }
}

class _OtherPageState extends State<OtherPage> {
  _OtherPageState() {
    _fontSize = _width / 15;
    _textStyle = TextStyle(fontSize: _fontSize, color: Colors.black87);
  }
  double _width = MediaQueryData.fromWindow(window).size.width;
  double _height = MediaQueryData.fromWindow(window).size.height;
  double _fontSize;
  TextStyle _textStyle;

  ExcelMgr _excelMgr = ExcelMgr();

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
    final sizedBox = SizedBox(height: _width * 5 / 100);
    return Column(
//      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        sizedBox,
        Divider(),
        sizedBox,
        _buildImportDetailDataButton(),
        sizedBox,
        Divider(),
        sizedBox,
        _buildImportExpenditureDataButton(),
        sizedBox,
        Divider(color: Colors.orange),
        sizedBox,
//        _buildImportDataFileButton(),
//        sizedBox,
//        Divider(),
//        sizedBox,
        _buildShareDataFileButton(),
        sizedBox,
        Divider(),
      ],
    );
  }

  Widget _buildImportDetailDataButton() {
    final title = RichText(
        textAlign: TextAlign.center,
        text: TextSpan(children: [
          TextSpan(text: "从xlsx文件", style: _textStyle),
          TextSpan(
              text: "导入随喜数据表",
              style: TextStyle(
                  fontSize: _fontSize * 1.5, color: Colors.blueAccent)),
        ]));
    return RaisedButton(
      child: FittedBox(child: title),
      onPressed: () async {
        final File file = await FilePicker.getFile(
            type: FileType.CUSTOM, fileExtension: "xlsx");
        if (null == file) {
          // 未选择文件
          return;
        }

        showLoading(context); // 显示等待画面

        List<int> bytes = file.readAsBytesSync();

        SpreadsheetDecoder decoder;
        try {
          decoder = SpreadsheetDecoder.decodeBytes(bytes, update: true);
        } catch (err) {
          showMsg(context, "请选择合法的xlsx文件");
          Navigator.of(context).pop(); // 取消等待画面
          return;
        }

        await Navigator.of(context).push(MaterialPageRoute(builder: (context2) {
          return ExcelPreviewSelectPage(
            title,
            decoder,
            onCommitFn: (String selectedTableName) async {
              String errMsg =
                  await _excelMgr.ImportDetailData(decoder, selectedTableName);

              if ((null == errMsg) || ("" == errMsg)) {
                showMsg(context, "导入成功！");
              } else {
                // 导入失败时，在预览界面显示错误信息，这里不做处理
//                msg = "导入失败！";
              }

              return errMsg;
            },
          );
        }));

        Navigator.of(context).pop(); // 取消等待画面
      },
    );
  }

  Widget _buildImportExpenditureDataButton() {
    final title = RichText(
        textAlign: TextAlign.center,
        text: TextSpan(children: [
          TextSpan(text: "从xlsx文件", style: _textStyle),
          TextSpan(
              text: "导入支出数据表",
              style:
                  TextStyle(fontSize: _fontSize * 1.5, color: Colors.orange)),
        ]));

    return RaisedButton(
      child: FittedBox(child: title),
      onPressed: () async {
        final File file = await FilePicker.getFile(
            type: FileType.CUSTOM, fileExtension: "xlsx");
        if (null == file) {
          // 未选择文件
          return;
        }

        showLoading(context); // 显示等待画面

        List<int> bytes = file.readAsBytesSync();

        SpreadsheetDecoder decoder;
        try {
          decoder = SpreadsheetDecoder.decodeBytes(bytes, update: true);
        } catch (err) {
          showMsg(context, "请选择合法的xlsx文件");
          Navigator.of(context).pop(); // 取消等待画面
          return;
        }

        await Navigator.of(context).push(MaterialPageRoute(builder: (context2) {
          return ExcelPreviewSelectPage(
            title,
            decoder,
            onCommitFn: (String selectedTableName) async {
              String errMsg = await _excelMgr.ImportExpenditureData(
                  decoder, selectedTableName);

              if ((null == errMsg) || ("" == errMsg)) {
                showMsg(context, "导入成功！");
              } else {
                // 导入失败时，在预览界面显示错误信息，这里不做处理
//                msg = "导入失败！";
              }

              return errMsg;
            },
          );
        }));

        Navigator.of(context).pop(); // 取消等待画面
      },
    );
  }

  Widget _buildImportDataFileButton() {
    return RaisedButton(
      child: FittedBox(child: Text("导入xlsx数据文件", style: _textStyle)),
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
      child: FittedBox(child: Text("分享数据文件", style: _textStyle)),
      onPressed: () async {
        String fullPath = _excelMgr.dataFileFullPath;

        await ShareExtend.share(fullPath, "file");
      },
    );
  }
}

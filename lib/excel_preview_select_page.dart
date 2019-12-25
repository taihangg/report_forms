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

class ExcelPreviewSelectPage extends StatefulWidget {
  final Widget title;
  final SpreadsheetDecoder decoder;
  final void Function(String tableName) onCommitFn;
  ExcelPreviewSelectPage(this.title, this.decoder,
      {@required this.onCommitFn}) {}

  @override
  State<StatefulWidget> createState() {
    return _ExcelPreviewSelectPageState();
  }
}

class _ExcelPreviewSelectPageState extends State<ExcelPreviewSelectPage> {
  _ExcelPreviewSelectPageState() {}

  double _width = MediaQueryData.fromWindow(window).size.width;
  double _height = MediaQueryData.fromWindow(window).size.height;
  String _selectedTable = "";
  Iterable<MapEntry<String, SpreadsheetTable>> _tables;

  @override
  void initState() {
    super.initState();
    _tables = widget.decoder.tables.entries;
    if (_tables.isNotEmpty) {
      _selectedTable = _tables.first.key;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FittedBox(child: widget.title),
        backgroundColor: Colors.grey[350],
      ),
      body: Builder(builder: (BuildContext context) {
        return _buildBody();
      }),
    );
  }

  Widget _buildAppBar() {
    return AppBar(
        title: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(children: [
              TextSpan(
                  text: "从xlsx文件\n",
                  style:
                      TextStyle(fontSize: _width / 15, color: Colors.black87)),
              TextSpan(
                  text: "导入随喜数据表",
                  style:
                      TextStyle(fontSize: _width / 15, color: Colors.orange)),
            ])));
  }

  Widget _buildBody() {
    return Column(
      children: [
        _buildTitle(),
        _buildContent(),
        Divider(thickness: 2.0, color: Colors.lightBlueAccent),
        _buildButtonRow(),
        SizedBox(height: _width / 20),
      ],
    );
  }

  Widget _buildTitle() {
    if (_tables.isEmpty) {
      return Card(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border.all(width: 0.5, color: Colors.grey[600]),
            borderRadius: BorderRadius.all(Radius.circular(6.0)),
          ),
          child: Text(
            "没有表格",
            style: TextStyle(fontSize: _width / 15, color: Colors.grey),
          ),
        ),
      );
    }

    return Scrollbar(
        child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_tables.length, (int index) {
                  return GestureDetector(
                    child: Card(
                      child: Container(
                        decoration: BoxDecoration(
                          color:
                              (_tables.elementAt(index).key == _selectedTable)
                                  ? Colors.yellow
                                  : Colors.grey[100],
                          border:
                              Border.all(width: 0.5, color: Colors.grey[600]),
                          borderRadius: BorderRadius.all(Radius.circular(6.0)),
                        ),
                        child: Text(
                          _tables.elementAt(index).key,
                          style: TextStyle(fontSize: _width / 15),
                        ),
                      ),
                    ),
                    onTap: () {
                      _selectedTable = _tables.elementAt(index).key;
                      setState(() {});
                    },
                  );
                }))));
  }

  Widget _buildContent() {
    final table = widget.decoder.tables[_selectedTable];
    if (null == table) {
      return Expanded(child: SizedBox());
    }

    final rows = <Widget>[];
    for (int r = 0; r < table.maxRows; r++) {
      final cols = <Widget>[];
      for (int c = 0; c < table.maxCols; c++) {
        cols.add(_buildBox(table.rows[r][c]));
      }
      rows.add(Row(children: cols));
      if (20 <= r) {
        break;
      }
    }

    return Expanded(
      child: Container(
        width: _width,
//      height: _height * 80 / 100,
        child: Scrollbar(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Scrollbar(
              child: SingleChildScrollView(
//          scrollDirection: Axis.horizontal,
                child: Container(
//            width: _width,
//                height: _height * 10 / 100,
                  child: Column(children: rows),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBox(dynamic v) {
    return Container(
      width: _width * 50 / 100,
      height: _width * 10 / 100,
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
          border: Border.all(width: 0.5, color: Colors.grey[600])),
//      child: FittedBox(
//        fit: BoxFit.fitHeight,
      child: Text(
        valueToString(v),
        style: TextStyle(fontSize: _width / 20),
        overflow: TextOverflow.ellipsis,
      ),
//      ),
    );
  }

  Widget _buildButtonRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        RaisedButton(
          child: Text(
            "取消",
            style: TextStyle(fontSize: _width / 15),
          ),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        RaisedButton(
          child: Text(
            "导入此表",
            style: TextStyle(fontSize: _width / 15),
          ),
          onPressed: () async {
            if (null != widget.onCommitFn) {
              showLoading(context);
              await Future.delayed(Duration(seconds: 1));

              widget.onCommitFn(_selectedTable);

              Navigator.of(context).pop();
            }
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

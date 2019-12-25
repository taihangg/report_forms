import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'excel_mgr.dart';
import 'common_util.dart';

class AddDetailDataPage extends StatefulWidget {
  final Widget title;
  AddDetailDataPage(this.title) {}

  @override
  State<StatefulWidget> createState() {
    return AddDetailDataPageState();
  }
}

class AddDetailDataPageState extends State<AddDetailDataPage> {
//  String _newText;
//  UserDefinedFestirvalEditorState();

  ExcelMgr _excelMgr =
      ExcelMgr(onFinishedFn: (ExcelMgr mgr, bool ok, String msg) {});

  double _width = MediaQueryData.fromWindow(window).size.width;
  double _height = MediaQueryData.fromWindow(window).size.height;

  double _fontSize;

  final _controller = TextEditingController();

  @override
  initState() {
    super.initState();

//    _controller.text = _testText;
    _fontSize = _width / 20;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FittedBox(child: widget.title),
        backgroundColor: Colors.grey[350],
      ),
      body: Builder(
        builder: (BuildContext context2) {
          return Scrollbar(
              child: SingleChildScrollView(child: _buildBody(context2)));
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Column(
      children: <Widget>[
        _buildReminder(),
        SizedBox(height: _width * 5 / 100),
        _buildInputTextBox(),
        SizedBox(height: _width * 5 / 100),
        _buildButtonRow(context),
        SizedBox(height: _width / 40),
      ],
    );
  }

  Widget _buildReminder() {
    return Column(
      children: <Widget>[
        SizedBox(height: 10),
        Center(
            child: Text("最后一次数据",
                style: TextStyle(fontSize: _fontSize, color: Colors.red))),
        Container(
          width: _width * 99 / 100,
//      height: _height * 60 / 100,
          decoration: BoxDecoration(
            color: Colors.grey[100],
//            border: Border.all(width: 0.5, color: Colors.black38),
          ),
          child: _buildLastDetailItem() ??
              Center(
                  child: Text("暂无数据", style: TextStyle(fontSize: _fontSize))),
        ),
      ],
    );
  }

  Widget _buildLastDetailItem() {
    final item = _excelMgr.lastDetailItem;
    if (null == item) {
      return null;
    }

    return _buildDetailDataRow(item);
  }

  Widget _buildDetailDataRow(DetailItem v) {
//    final maxTextLengh = 15;
    List<dynamic> datas = [
      v.rowIndex,
      v.commitTimeText,
//      (v.name.length < maxTextLengh)
//          ? v.name
//          : v.name.substring(0, maxTextLengh - 1), // 字数太多，显示不友好
      v.name,
      valueToString(v.money),
    ];
    return _buildDetailRow(datas, alignment: Alignment.centerLeft);
  }

  Widget _buildDetailRow(List<dynamic> datas,
      {Color color, Alignment alignment}) {
    List<double> widthList = [
      _width * 10 / 100,
      _width * 30 / 100,
      _width * 51 / 100,
      _width * 10 / 100,
    ];
    assert(widthList.length == datas.length);
    return FittedBox(
        child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(datas.length, (i) {
              return _buildBox(datas[i], widthList[i],
                  color: color, alignment: alignment);
            })));
  }

  Widget _buildBox(dynamic v, double width,
      {Color color, Alignment alignment}) {
    final decoration = BoxDecoration(
        color: color, //?? Colors.grey[100],
        border: Border.all(width: 0.5, color: Colors.grey[600]));
    final style = TextStyle(fontSize: _width / 25);

    final str = valueToString(v);
    final text = Text(str,
        style: style,
//      softWrap: true,
        overflow: TextOverflow.ellipsis);

    if (25 < str.length) {
      return Container(
          height: _width * 10 / 100,
          width: width,
          alignment: alignment ?? Alignment.centerRight,
          decoration: decoration,
          child: text);
    }

    return Container(
        height: _width * 10 / 100,
        width: width,
        alignment: alignment ?? Alignment.centerRight,
        decoration: decoration,
        child: FittedBox(child: text));
  }

  Widget _buildInputTextBox() {
    return Scrollbar(
        child: SingleChildScrollView(
            child: Container(
      width: _width * 9 / 10,
      height: _height * 60 / 100,
//      decoration: BoxDecoration(
//        color: Colors.blue[300],
//        border: Border.all(width: 0.5, color: Colors.black38),
//        borderRadius: BorderRadius.all(Radius.circular(6.0)),
//      ),
      child: TextFormField(
        controller: _controller,
//        autofocus: true,
        maxLines: null,
        minLines: 25,
//        expands: true,
//        maxLength: 100000000000,
//        maxLengthEnforced: false,
        decoration: InputDecoration(
          hintText: "请输入新增数据!",
          hintStyle: TextStyle(fontSize: _fontSize, color: Colors.grey[500]),
          filled: true,
          fillColor: Colors.grey[200],
        ),
        style: TextStyle(fontSize: _fontSize),
        onChanged: (String str) {
//          _newText = str;
        },
      ),
    )));
  }

  Widget _buildButtonRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        RaisedButton.icon(
          icon: Icon(Icons.clear),
          label: Text("清空", style: TextStyle(fontSize: _fontSize)),
          onPressed: () {
            // for test
            if ("" != _controller.text) {
              _controller.text = "";
            }

//            _controller.text = "";
          },
        ),
        RaisedButton.icon(
          icon: Icon(Icons.done),
          label: Text("提交", style: TextStyle(fontSize: _fontSize)),
          onPressed: () async {
            if (!_excelMgr.ready) {
              showMsg(context, "请允许app读写存储的权限");
              return;
            }

            showLoading(context); // 显示等待画面

            await Future.delayed(Duration(milliseconds: 500)); // 等待loading画面显示

            List<List<String>> parsedLines = [];
            final msg = _parse(_controller.text, parsedLines);
            if ((null != msg) && ("" != msg)) {
              Navigator.of(context).pop(); // 取消等待画面
              showMsg(context, msg);
              return;
            }

            bool ok =
                await _excelMgr.AddDetailData(parsedLines.reversed.toList());

            Navigator.of(context).pop(); // 取消等待画面

            String msg2;
            if (ok) {
              _controller.text = "";
              msg2 = "添加成功!";
            } else {
              msg2 = "添加数据失败!";
            }
            showMsg(context, msg2);

            FocusScope.of(context).requestFocus(FocusNode()); // 失焦，隐藏键盘
//            setState(() {});

            return;
          },
        ),
      ],
    );
  }

  String _parse(String data, List<List<String>> parsedLines) {
    String msg;
    final lines = _controller.text.split("\n");
    String lastLine;
    int lineNum = lines.length + 1;

    RegExp re = RegExp(
        r"(?<submitter>^.*)\t(?<dateTime>[0-9]{4}[^0-9][0-9]{1,2}[^0-9][0-9]{1,2}[^0-9][0-9]{1,2}[^0-9][0-9]{1,2}[^0-9][0-9]{1,2})\t");
    for (String line in lines.reversed) {
//      int x;
//      await x;

      lineNum--;
//      if (0 == (lineNum % 50)) {
//        // 给外面的等待动画运行一下
//        int x;
//        await x;
////         await Future.delayed(Duration(milliseconds: 300));
//      }
//              line.split("\t");

      final matches = re.allMatches(line);

      if (matches.isEmpty) {
        if (null == lastLine) {
          lastLine = line;
        } else {
          lastLine = line + " " + lastLine;
        }
        continue;
      }

      assert(1 == matches.length);
      final match = matches.first;

      String nameMoney;
      if (null != lastLine) {
        nameMoney = line.substring(match.end) + lastLine;
        lastLine = null;
      } else {
        nameMoney = line.substring(match.end);
      }
      int moneyIndex = nameMoney.lastIndexOf("\t");
      if (moneyIndex < 0) {
        msg = "第$lineNum行，金额数据不正确：\n$line";
        break;
      }

      String submitter = match.namedGroup("submitter");
      String dateTime = match.namedGroup("dateTime");
      String name = nameMoney.substring(0, moneyIndex);

      String money = "";
      if (moneyIndex + 1 < nameMoney.length) {
        money = nameMoney.substring(moneyIndex + 1).trimRight();
        if ("" == money) {
        } else {
          try {
            double.parse(money);
          } catch (err) {
            msg = "第$lineNum行，金额数据不正确：\n$line";
            break;
          }
        }
      }
      List<String> parsedLine = [submitter, dateTime, name, money];
      parsedLines.add(parsedLine);
    }

    return msg;
  }
}

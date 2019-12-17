import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'excel_mgr.dart';
import 'common_util.dart';

class AddDetailDataPage extends StatefulWidget {
  String Function(String) onSaveFn;
  AddDetailDataPage() {}

  @override
  State<StatefulWidget> createState() {
    return AddDetailDataPageState();
  }
}

class AddDetailDataPageState extends State<AddDetailDataPage> {
//  String _newText;
//  UserDefinedFestirvalEditorState();

  ExcelMgr _excelMgr = ExcelMgr(onFinishedFn: (bool ok, String msg) {});

  double _width = MediaQueryData.fromWindow(window).size.width;
  double _height = MediaQueryData.fromWindow(window).size.height;

  double _fontSize;

  final _testText = """能敏	2019/10/28 15:18:35	梁绍琼	20
能敏	2019/10/28 15:42:56	文素芳	
李军帅🍀占卜	2019/10/28 22:28:19	申里娜	1
李军帅🍀占卜	2019/10/28 22:28:32	李军帅	1
杨蕾	2019/10/28 23:33:13	杨蕾	2
杨蕾	2019/10/29 8:51:52	杨蕾	2
海天一线	2019/10/29 13:36:02	孙景	5
桂英	2019/10/22 12:56:06	祈福:冉桂英，周诗媛，周昌平，冉仁祥，冉仁国，冉仁明，冉立琴，史新华，雷晓笛，余诗兰，张伟，冉可，童雨，冉丹，陈诗诗，冉智琳，冉兴，张力，冉子舰，冉沅鑫，周昌荣全家，杨菲，曹曙光，吴世芳，周伟，周颜，黄桂英，赵小凤，朱江，赵勇，陈涛，赵玲玲，杨军，张春，张莹心，刘小琴，张波，付孝伟，张洋，张丽娟，韦侩伦，韦纯，韦小蓉，韦小芳，韦小芬，冉仁淑(大小)，何太国，何太才全家，陈世孝全家，陈世忠全家，陈世弟全家，陈世珍全家，冉仁杰全家，张锡光全家，张锡才全家，张斌全家，刘晓昆，高盛明，赵慧君，李洪成，王玉梅，张建国，李光碧，汪继昌，韦蓉，邓开维，李丹，段小林，曹德忠，马天秀，李文秀，马天俊，马天敏，马天群，谭德发，谭德英，谭德珍，谭德树，谭德惠，杨孝群，洪有成，王成贵，王成富，郑洪林，王涪生，潘天剑，况德祥，刘力，李丽惠，蒋萍，詹梅，蒋世莲，包福震，冯雪梅，范明全家，陈宏宇，林朝阳，王崇兰，冯军，覃明，周朝霞，何恩跃，张阿忠，杨德明等亲朋好友、同学、同事、知友、街坊邻居等所有好友...






离世:周氏历代祖宗及六亲眷属，冉氏历代祖宗及六亲眷属，冉绍清，张淑华，冉桂芝，冉仁孝，周永端，周兴喜，周天锡，文帮群，周天京，凌承惠，周天成，伍祥玉，周昌琴，赵怀锐，周昌立，周昌全，周昌国，杨文富，文建明，冉仁福，冉仁玉，张友均，张锡珍，宫燕渝，陶建华，朱庭俊，赵志强，侯海涛，王明金，邓树良，晏裕孝，谭银忠，龙世碧，袁晓蓉，徐芳，廖新秋，王正祥，原渝中区棉絮街街坊邻居等亲朋好友、同学、同事、知友等应写末写...	50""";
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
//      appBar: AppBar(title: Center(child: Text("新增数据"))),
      body: Scrollbar(
        child: SingleChildScrollView(
          child: _buildPage(),
        ),
      ),
    );
  }

  _showMsg(String msg) {
    Scaffold.of(context).showSnackBar(SnackBar(
      content: Text(
        msg,
        style: TextStyle(color: Colors.red, fontSize: 30),
      ),
      duration: Duration(seconds: 5),
      backgroundColor: Colors.tealAccent,
//    action: SnackBarAction(
//      label: "button",
//      onPressed: () {
//        print("in press");
//      },
//    ),
    ));
  }

  Widget _buildPage() {
    return Column(
      children: <Widget>[
        _buildReminder(),
        SizedBox(height: _width * 5 / 100),
        _buildInputTextBox(),
        SizedBox(height: _width * 5 / 100),
        _buildButtonRow(),
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
      v.commitTime,
//      (v.name.length < maxTextLengh)
//          ? v.name
//          : v.name.substring(0, maxTextLengh - 1), // 字数太多，显示不友好
      v.name,
      v.money
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

    final str = _toString(v);
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

  String _toString(dynamic v) {
    if (null == v) {
      return " ";
    }

    switch (v.runtimeType) {
      case String:
        {
          if ("" == v) {
            return " ";
          }
          return v;
        }
      case double:
        {
          return (v as double).toStringAsFixed(2);
        }
      case int:
        {
          return "$v";
        }
      case DateInt:
        {
          return _formatDateInt(v);
        }
      default:
        {
          assert(false);
          break;
        }
    }
  }

  String _formatDateInt(DateInt v) {
    return "${v.year}/${v.month}/${v.day}";
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

  Widget _buildButtonRow() {
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
            } else {
              _controller.text = _testText;
            }

//            _controller.text = "";
          },
        ),
        RaisedButton.icon(
          icon: Icon(Icons.done),
          label: Text("提交", style: TextStyle(fontSize: _fontSize)),
          onPressed: () async {
            if (!_excelMgr.ready) {
              _showMsg("请允许app读写存储的权限");
              return;
            }

            // 显示等待画面
            showDialog(
                context: context,
                builder: (BuildContext context) {
                  return Column(
                    children: <Widget>[
                      buildLoadingView(),
                      Card(
                        color: Colors.lightBlueAccent.withOpacity(0.9),
                        child: Text("正在处理，请稍等……",
                            style: TextStyle(fontSize: _width / 15)),
                      )
                    ],
                  );
                });

            await Future.delayed(Duration(milliseconds: 500)); // 等待loading画面显示

            List<List<String>> parsedLines = [];
            final msg = _parse(_controller.text, parsedLines);
            if ((null != msg) && ("" != msg)) {
              _showMsg(msg);
              return;
            }

            await _excelMgr.AddDetailData(parsedLines.reversed.toList());
            Navigator.of(context).pop();

            _controller.text = "";
            FocusScope.of(context).requestFocus(FocusNode()); // 失焦，隐藏键盘
            setState(() {});

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
        msg = "第$lineNum行：金额数据不正确：\n$line";
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
            msg = "第$lineNum行：金额数据不正确：\n$line";
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

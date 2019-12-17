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

class ReportFormPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _ReportFormPageState();
  }
}

class _ReportFormPageState extends State<ReportFormPage> {
  _ReportFormPageState() {
    Future.delayed(Duration(seconds: 1), () {
      _excelMgr = ExcelMgr(onFinishedFn: _onExcelMgrFinished);
    });
  }

  double _width = MediaQueryData.fromWindow(window).size.width;
  double _height = MediaQueryData.fromWindow(window).size.height;

  ExcelMgr _excelMgr;

  GlobalKey _summaryWidgetKey = GlobalKey();
  List<GlobalKey> _statisticsWidgetKeyList = [];
  GlobalKey _expenditureWidgetKey = GlobalKey();
  List<GlobalKey> _detailWidgetKeyList = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
//      appBar: AppBar(title: Center(child: Text("分享"))),
      body: Builder(builder: (BuildContext context) {
        return _buildPage(context);
      }),
    );
  }

  Widget _buildPage(BuildContext context) {
    if (_initing) {
      return buildLoadingView();
    }

    return Column(
//      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        SizedBox(height: _width * 3 / 100),
        _buildShareButton(),
        Divider(),
//        SizedBox(height: _width * 5 / 100),
        _buildBody(context),
        SizedBox(height: _width * 5 / 100),
      ],
    );
  }

  Widget _buildShareButton() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
//        RaisedButton.icon(
////          icon: Icon(Icons.camera_alt),
//          icon: Icon(Icons.refresh),
//          label: Text("刷新", style: TextStyle(fontSize: _width / 20)),
//          onPressed: () {
//            setState(() {});
//          },
//        ),
        RaisedButton.icon(
          icon: Icon(Icons.share),
          label: Text("分享报表截图", style: TextStyle(fontSize: _width / 20)),
          onPressed: () async {
            // 如果分享的图片名字一样，微信、qq的缩略图不会变化，可以用时间戳组合命名

            int show = 0;
            if (0 == show) {
              final path = _excelMgr.path ?? "/storage/emulated/0/供灯报表数据";
              try {
                String fullPath = path + "/summary.png";
                await saveAsPicture(_summaryWidgetKey, fullPath);
                final list = [fullPath];

                for (int i = 0; i < _statisticsWidgetKeyList.length; i++) {
                  fullPath = path + "/statistics${i + 1}.png";
                  await saveAsPicture(_statisticsWidgetKeyList[i], fullPath);
                  list.add(fullPath);
                }

                fullPath = path + "/expenditure.png";
                await saveAsPicture(_expenditureWidgetKey, fullPath);
                list.add(fullPath);

                for (int i = 0; i < _detailWidgetKeyList.length; i++) {
                  fullPath = path + "/detail${i + 1}.png";
                  await saveAsPicture(_detailWidgetKeyList[i], fullPath);
                  list.add(fullPath);
                }

//                final dir = await _defaultExportDirectory();
//                final file = File(dir.path + "/abc.png");

                await ShareExtend.shareMultiple(list, "image");
              } catch (err) {
                debugPrint("error in share: $err");
              }
            }
            if (1 == show) {
              final tsStr = DateTime.now().toIso8601String();
              Map<String, List<int>> files = {
                "summary_${tsStr}.png": await getImageData(_summaryWidgetKey)
              };

              for (int i = 0; i < _statisticsWidgetKeyList.length; i++) {
                files["statistics_${i + 1}_${tsStr}.png"] =
                    await getImageData(_statisticsWidgetKeyList[i]);
              }
              files["expenditure_${tsStr}.png"] =
                  await getImageData(_expenditureWidgetKey);

              for (int i = 0; i < _detailWidgetKeyList.length; i++) {
                files["detail_${i + 1}_${tsStr}.png"] =
                    await getImageData(_detailWidgetKeyList[i]);
              }

              await esys_flutter_share.Share.files('title', files, "image/png",
                  text: 'text');
            }
            if (2 == show) {
              final statisticsData =
                  await getImageData(_detailWidgetKeyList[0]);
              await esys_flutter_share.Share.file(
                "分享到：",
                "统计信息.png",
                statisticsData,
//              file.readAsBytesSync(),
//              '*/*',
                "image/png",
                text: "text hello",
              );
            }
          },
        ),
      ],
    );
  }

  Future<Directory> _defaultExportDirectory() async {
    Directory dir;

    if (defaultTargetPlatform == TargetPlatform.android) {
      dir = await getExternalStorageDirectory();
//      dir = Directory("/storage/emulated/0/供灯报表数据");
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      dir = await getApplicationDocumentsDirectory();
    }

    return dir;
  }

  String _msg = "";
  Color _color = Colors.grey;

  bool _initing = true;
  bool _excelMgrReady = false;
  void _onExcelMgrFinished(bool ok, String msg) {
    _initing = false;
    _excelMgrReady = ok;
    _msg = msg;
    _color = Colors.red;
    if (mounted) {
      setState(() {});
    }
  }

  Widget _buildBody(BuildContext context) {
    if (!_excelMgrReady) {
      return _buildErrorMsgWidget(_msg, _color);
    }

    return Expanded(
      child: Scrollbar(
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              _buildSummary(),
//              SizedBox(height: _width * 2 / 100),
              ..._buildStatisticsWidgetList(),
              _buildExpenditureWidget(),
              ..._buildDetailWidgetList(),
//              Divider(),
            ],
          ),
        ),
      ),
    );
  }

//  Widget _buildBody(BuildContext context) {
//    if (!_excelMgrReady) {
//      return _buildErrorMsgWidget(_msg, _color);
//    }
//
//    _statisticsWidgetKeyList = [
//      GlobalKey(),
//      GlobalKey(),
//      GlobalKey(),
//      GlobalKey(),
//    ];
//
//    return Expanded(
//      child: Scrollbar(
//        child: ListView.builder(
//          itemBuilder: (BuildContext context, int index) {
//            if (index < 1) {
//              return _buildSummary();
//            } else if (index - 1 < 4) {
//              return _buildStatisticsWidget(
//                  _statisticsWidgetKeyList[index - 1],
//                  "",
//                  _excelMgr.statisticsDailyDataList
//                      .getRange(0, _excelMgr.statisticsDailyDataList.length));
//            } else if (index - 1 - 4 < 1) {
//              return _buildExpenditureWidget();
//            } else if (index - 1 - 4 - 1 < 1) {
//              return _buildDetailWidget();
//            }
//          },
////          children: <Widget>[
////            _buildSummary(),
//////              SizedBox(height: _width * 2 / 100),
////            ..._buildStatisticsWidgetList(),
////            _buildExpenditureWidget(),
////            _buildDetailWidget(),
//////              Divider(),
////          ],
//        ),
//      ),
//    );
//  }

  Widget _buildSummary() {
    return RepaintBoundary(
      key: _summaryWidgetKey,
      child: Card(
        elevation: 5.0,
        color: Colors.grey[100],
        child: Container(
            width: _width * 95 / 100,
            child: Text(_excelMgr.summary,
                style: TextStyle(fontSize: _width / 20))),
      ),
    );
  }

  Widget _buildErrorMsgWidget(String msg, Color color) {
    return Container(
      width: _width * 9 / 10,
      color: Colors.grey[200],
      child: Text(msg, style: TextStyle(fontSize: _width / 15, color: color)),
    );
  }

  List<Widget> _buildStatisticsWidgetList() {
    List<Widget> children = [];
    int keyIndex = 0;
    int pageLimit = 100;
    int num =
        (_excelMgr.statisticsDailyDataList.length + pageLimit - 1) ~/ pageLimit;
    for (int start = 0;
        start < _excelMgr.statisticsDailyDataList.length;
        start += pageLimit) {
      if (_statisticsWidgetKeyList.length <= keyIndex) {
        _statisticsWidgetKeyList.add(GlobalKey());
      }
      final key = _statisticsWidgetKeyList[keyIndex];

      final end = (start + pageLimit < _excelMgr.statisticsDailyDataList.length)
          ? (start + pageLimit)
          : _excelMgr.statisticsDailyDataList.length;
      final list = _excelMgr.statisticsDailyDataList.getRange(start, end);

      children
          .add(_buildStatisticsWidget(key, " ${keyIndex + 1}/${num}", list));

      keyIndex++;
    }

    return children;
  }

  int _statisticsWidthTime = 1;
  Widget _buildStatisticsWidget(GlobalKey key, String titleTail,
      Iterable<StatisticsDailyDataItem> datas) {
    return RepaintBoundary(
      key: key,
      child: Card(
        elevation: 5.0,
        color: Colors.grey[100],
        child: Container(
          width: _width * _statisticsWidthTime,
          child: Column(
            children: [
              Divider(),
              Container(
                  width: _width,
                  alignment: Alignment.center,
                  child: Text("统计数据" + titleTail,
                      style:
                          TextStyle(fontSize: _width / 15, color: Colors.red))),
              _buildStatisticsTitleRow(),
//              ListView.builder(
//                  itemCount: list.length,
//                  physics: const NeverScrollableScrollPhysics(),
//                  itemBuilder: (BuildContext context, int index) {
//                    return _buildStatisticsDataRow(datas.first);
//                  }),
//              ...datas.map((item) {
//                return _buildStatisticsDataRow(item);
//              }).toList(),
              ...List.generate(datas.length, (index) {
                return _buildStatisticsDataRow(datas.elementAt(index));
              }),
              Divider(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsTitleRow() {
    List<String> datas = ["序号", "日期", "当日随喜", "累计随喜", "当日支出", "累计支出", "剩余"];
    return _buildStatisticsRow(datas,
        color: Colors.lightBlueAccent.withOpacity(0.9),
        alignment: Alignment.center);
  }

  Widget _buildStatisticsDataRow(StatisticsDailyDataItem v) {
//    print("${v.ID}");
    List<dynamic> datas = [
      v.rowIndex,
//      v.pos ,
      v.dateInt,
      v.dailyIncomeMoney,
      v.sumIncomeMoney,
      v.dailyExpenditureMoney,
      v.sumExpenditureMoney,
      v.leftMoney,
    ];
    return _buildStatisticsRow(datas);
  }

  Widget _buildStatisticsRow(List<dynamic> datas,
      {Color color, Alignment alignment}) {
    List<double> widthList = [
      _width * 8 / 100,
      _width * 30 / 100,
      _width * 14 / 100,
      _width * 14 / 100,
      _width * 14 / 100,
      _width * 14 / 100,
      _width * 14 / 100,
    ];
    assert(widthList.length == datas.length);
    return Container(
        width: _width,
        height: _width * 10 / 100,
        child: FittedBox(
            child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(datas.length, (i) {
                  return _buildBox(datas[i], widthList[i],
                      color: color,
                      alignment: alignment,
                      times: _statisticsWidthTime);
                }))));
  }

  Widget _buildBox(dynamic v, double width,
      {Color color, Alignment alignment, int times = 1}) {
    final decoration = BoxDecoration(
        color: color, //?? Colors.grey[100],
        border: Border.all(width: 0.5, color: Colors.grey[600]));
    final style = TextStyle(fontSize: times * _width / 25);

    final str = _toString(v);
    final text = Text(str,
        style: style,
//      softWrap: true,
        overflow: TextOverflow.ellipsis);

    if (20 < str.length) {
      return Container(
          height: times * _width * 10 / 100,
          width: times * width,
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

  Widget _buildExpenditureWidget() {
    return RepaintBoundary(
      key: _expenditureWidgetKey,
      child: Card(
        elevation: 5.0,
        color: Colors.grey[100],
        child: Container(
          width: _width,
          child: Column(
            children: [
              Divider(),
              Container(
                  width: _width,
                  alignment: Alignment.center,
                  child: Text("支出清单",
                      style:
                          TextStyle(fontSize: _width / 15, color: Colors.red))),
              _buildExpenditureTitleRow(),
              ...List.generate(_excelMgr.expenditureDataItemList.length, (i) {
                return _buildExpenditureDataRow(
                    _excelMgr.expenditureDataItemList[i]);
              }),
              Divider(),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateInt(DateInt v) {
    return "${v.year}/${v.month}/${v.day}";
  }

  Widget _buildExpenditureTitleRow() {
    List<String> datas = [
      "序号",
      "日期",
      "名称",
      "说明",
      "单价",
      "数量",
      "总价",
      "运费",
      "折扣",
      "总金额",
    ];
    return _buildExpenditureRow(datas,
        color: Colors.lightBlueAccent.withOpacity(0.9),
        alignment: Alignment.center);
  }

  Widget _buildExpenditureDataRow(ExpenditureDataItem v) {
    List<dynamic> datas = [
      v.ID,
      v.dateInt,
      v.name,
      v.comment,
      v.price,
      v.count,
      v.totalPrice,
      v.transportationExpense,
      v.discount,
      v.finalMoney,
    ];
    return _buildExpenditureRow(datas);
  }

  Widget _buildExpenditureRow(List<dynamic> datas,
      {Color color, Alignment alignment}) {
    List<double> widthList = [
      _width * 7 / 100,
      _width * 25 / 100,
      _width * 15 / 100,
      _width * 15 / 100,
      _width * 10 / 100,
      _width * 10 / 100,
      _width * 15 / 100,
      _width * 10 / 100,
      _width * 10 / 100,
      _width * 15 / 100,
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

  int _detailAllShowCount = 200;
  int _detailPerPageLimit = 100;
  List<Widget> _buildDetailWidgetList() {
    List<Widget> children = [];
    int keyIndex = 0;

    int showCount = _detailAllShowCount; // 实际显示数量
    int firstPos = _excelMgr.detailList.length - _detailAllShowCount;
    if (firstPos < 0) {
      firstPos = 0;
      showCount = _excelMgr.detailList.length;
    }
    int pageCount =
        (showCount + _detailPerPageLimit - 1) ~/ _detailPerPageLimit;

    for (int index = firstPos;
        index < _excelMgr.detailList.length;
        index += _detailPerPageLimit) {
      if (_detailWidgetKeyList.length <= keyIndex) {
        _detailWidgetKeyList.add(GlobalKey());
      }
      final key = _detailWidgetKeyList[keyIndex];

      final end = (index + _detailPerPageLimit < _excelMgr.detailList.length)
          ? (index + _detailPerPageLimit)
          : _excelMgr.detailList.length;
      final list = _excelMgr.detailList.getRange(index, end);

      children
          .add(_buildDetailWidget(key, " ${keyIndex + 1}/${pageCount}", list));

      keyIndex++;
    }

    return children;
  }

  Widget _buildDetailWidget(
      GlobalKey key, String titleTail, Iterable<DetailItem> datas) {
    return Card(
      elevation: 5.0,
      child: Container(
        width: _width,
        alignment: Alignment.center,
        child: FittedBox(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                color: Colors.grey[100],
                width: _width * 9 / 100,
                alignment: Alignment.topCenter,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Divider(),
                    Container(
                        width: _width * 10 / 100,
                        height: _width * 10 / 100,
                        alignment: Alignment.topCenter,
                        child: Text(" ",
                            style: TextStyle(
                                fontSize: _width / 15, color: Colors.red))),
                    _buildBox("序号", _width * 10 / 100,
                        color: Colors.lightBlueAccent.withOpacity(0.9),
                        alignment: Alignment.center),
                    ...List.generate(datas.length, (i) {
                      return _buildBox(
                          datas.elementAt(i).rowIndex, _width * 10 / 100,
                          alignment: Alignment.center);
                    }),
                    Divider(),
                  ],
                ),
              ),
              RepaintBoundary(
                key: key,
                child: Container(
                  color: Colors.grey[100], // 设置背景色，不然截图是黑的
                  width: _width * 90 / 100,
                  alignment: Alignment.topCenter,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Divider(),
                      Container(
                          width: _width * 90 / 100,
                          height: _width * 10 / 100,
                          alignment: Alignment.topCenter,
                          child: FittedBox(
                              child: Text("随喜与名单记录" + titleTail,
                                  style: TextStyle(
                                      fontSize: _width / 15,
                                      color: Colors.red)))),
                      _buildDetailTitleRow2(),
                      ...List.generate(datas.length, (i) {
                        return _buildDetailDataRow(datas.elementAt(i));
                      }),
                      Divider(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailTitleRow2() {
    List<String> datas = [
//      "序号",
      "提交时间",
      "姓名",
      "金额",
    ];
    return _buildDetailRow(datas,
        color: Colors.lightBlueAccent.withOpacity(0.9),
        alignment: Alignment.center);
  }

  Widget _buildDetailDataRow(DetailItem v) {
//    final maxTextLengh = 15;
    List<dynamic> datas = [
//      v.rowIndex,
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
      _width * 30 / 100,
      _width * 50 / 100,
      _width * 10 / 100,
    ];
    assert(widthList.length == datas.length);
    return /*FittedBox(
      fit: BoxFit.fill,
      child: */
        Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(datas.length, (i) {
        return _buildBox(datas[i], widthList[i],
            color: color, alignment: alignment);
      }),
//      ),
    );
  }
}

import 'dart:math';
import 'dart:ui';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:share_extend/share_extend.dart';
import 'common_util.dart';
import 'file_storage.dart';
import 'excel_mgr.dart';

class ExportNameListPage extends StatefulWidget {
  final Widget title;
  ExportNameListPage(this.title) {}

  @override
  State<StatefulWidget> createState() {
    return _ExportNameListPageState();
  }
}

class _ExportNameListPageState extends State<ExportNameListPage> {
  _ExportNameListPageState() {
    _excelMgr = ExcelMgr(onUpdatedFn: _onExcelMgrFinishedOrUpdate);

//    final today = DateTime.now();
//    final yesterday = DateTime(today.year, today.month, today.day - 1);
//    _selectedDetailEndDateInt = DateInt(yesterday);
//    _selectedDetailEndDateText = formatDateInt(_selectedDetailEndDateInt);

    _init();
  }

  double _width = MediaQueryData.fromWindow(window).size.width;
  double _height = MediaQueryData.fromWindow(window).size.height;

  ExcelMgr _excelMgr;

  final int _defaultLatestDetailDataDayCount = 15;

  DateInt _detailStartDateInt;
  String _detailStartDateText;

  _updateDetailStartDateInt(DateInt di) {
    _detailStartDateInt = di;
    _detailStartDateText = formatDateInt(_detailStartDateInt);
  }

  DateInt _selectedDetailEndDateInt;
  String _selectedDetailEndDateText;

  _updateSelectedDetailEndDateInt(DateInt di) {
    _selectedDetailEndDateInt = di;
    if (_selectedDetailEndDateInt.data < _detailStartDateInt.data) {
      _selectedDetailEndDateInt = _detailStartDateInt;
    }
    _selectedDetailEndDateText = formatDateInt(_selectedDetailEndDateInt);
  }

  int _actualDetailEndDate;

  int _detailListFirstShowPos;

  KeyValueFile _KVFile = KeyValueFile();
  final String _lastExportEndDateKey = "lastExportEndDate";
  DateInt _lastExportEndDateInt;

  @override
  void dispose() {
    _excelMgr.cancelNotify();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FittedBox(child: widget.title),
        backgroundColor: Colors.grey[350],
      ),
      body: _buildBody(),
    );
  }

  _init() async {
    int lastExportEndDate = await _KVFile.getInt(key: _lastExportEndDateKey);
    if (null != lastExportEndDate) {
      _lastExportEndDateInt = DateInt.fromInt(lastExportEndDate);
      if (_excelMgr.ready) {
        _updateDetailStartDateInt(_lastExportEndDateInt.nextDay);

        if (_excelMgr.detailList.isNotEmpty) {
          _updateSelectedDetailEndDateInt(
              _excelMgr.detailList.last.commitDateInt.prevousDay);
        }

        _refreshDetailListFirstShowPos(_excelMgr);
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  String _msg = "";
  Color _color = Colors.grey;

  bool _initing = true;

  void _onExcelMgrFinishedOrUpdate(ExcelMgr mgr, bool ok, String errMsg) async {
    _initing = false;

    _msg = errMsg;
    _color = Colors.red;

    if (ok) {
      if (null == _lastExportEndDateInt) {
        // 默认值
        final today = DateTime.now();
        final startDate = DateTime(today.year, today.month,
            today.day - _defaultLatestDetailDataDayCount);
        _updateDetailStartDateInt(DateInt(startDate));
      } else {
        _updateDetailStartDateInt(_lastExportEndDateInt.nextDay);
      }

      if (mgr.detailList.isNotEmpty) {
        _updateSelectedDetailEndDateInt(
            mgr.detailList.last.commitDateInt.prevousDay);
      }

      _refreshDetailListFirstShowPos(mgr);
    }
    if (mounted) {
      setState(() {});
    }
  }

  Widget _buildBody() {
    if (_initing) {
      return buildLoadingCard();
    }

    if (!_excelMgr.ready) {
      return _buildErrorMsgWidget(_msg, _color);
    }

    final double height = 5;

    return Column(
      children: <Widget>[
        Divider(height: height),
        _buildShareButton(),
        Divider(height: height),
        _buildLastExportEndDateWidget(),
        Divider(height: height),
        _buildStartDateButton(),
        Divider(height: height),
        _buildEndDateButton(),
        Divider(height: height),
        _buildContent(),
        Divider(height: height),
      ],
    );
  }

  Widget _buildLastExportEndDateWidget() {
    String text;
    if (null != _lastExportEndDateInt) {
      text = "上次导出截止日期：" + formatDateInt(_lastExportEndDateInt);
    } else {
      text = "尚未有导出记录";
    }

    return Container(
        color: Colors.grey[300],
        child: FittedBox(
            child: Text(
          text,
          style: TextStyle(fontSize: _width / 14),
//        textAlign: TextAlign.center,
        )));
  }

  Widget _buildErrorMsgWidget(String msg, Color color) {
    return Container(
      width: _width * 9 / 10,
      color: Colors.grey[200],
      child: Text(msg, style: TextStyle(fontSize: _width / 15, color: color)),
    );
  }

  Widget _buildShareButton() {
    return FittedBox(
        child: RaisedButton.icon(
      color: Colors.lightGreenAccent,
      icon: Icon(Icons.share, size: _width / 13),
      label: Text("导出/分享名单文件", style: TextStyle(fontSize: _width / 13)),
      onPressed: () async {
        // 如果分享的图片名字一样，微信、qq的缩略图不会变化，可以用时间戳组合命名

        if ((null == _text) || ("" == _text)) {
          showMsg(context, "当前内容为空!");
        }

        assert(null != _detailListFirstShowPos);
        final firstDate =
            _excelMgr.detailList[_detailListFirstShowPos].commitDateInt.data;
        final lastDate = _selectedDetailEndDateInt.data;

        String fullPath =
            defaultExportFileDir + "/nameList-${firstDate}-${lastDate}.txt";
        try {
          final file = File(fullPath);
          final exist = await file.exists();
          if (!exist) {
            await file.create(recursive: true);
          }
          await file.writeAsString(_text);
          await ShareExtend.share(fullPath, "file");

          _KVFile.setInt(key: _lastExportEndDateKey, value: lastDate);
//          _KVFile.setInt(
//              key: _lastExportEndDateKey, value: _actualDetailEndDate);
          _lastExportEndDateInt = _selectedDetailEndDateInt;

          _updateDetailStartDateInt(_lastExportEndDateInt.nextDay);

          _updateSelectedDetailEndDateInt(
              _excelMgr.detailList.last.commitDateInt.prevousDay);

          _refreshDetailListFirstShowPos(_excelMgr);

//          _text = "";

          setState(() {});
        } catch (err) {
          debugPrint("error in share: $err");
        }
      },
    ));
  }

  Widget _buildStartDateButton() {
    return GestureDetector(
      child: FittedBox(
          child: Card(
        color: Colors.yellow,
        child: Container(
          alignment: Alignment.center,
          child: FittedBox(
            child: Text(
              "起始显示日期：" + _detailStartDateText,
              style: TextStyle(fontSize: _width / 14),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      )),
      onTap: () async {
        final period = _excelMgr.getDetailDatePeriod();
        assert(null != period);

        DateInt firstDateInt;
        DateInt lastDateInt;
        DateInt initialDateInt;
        if (null == period) {
          DateInt todayInt = DateInt(DateTime.now());
          firstDateInt = todayInt;
          lastDateInt = todayInt;
          initialDateInt = todayInt;
        } else {
          firstDateInt = period[0];
          lastDateInt = period[1];
          initialDateInt = _selectedDetailEndDateInt;

          if (_detailStartDateInt.data < firstDateInt.data) {
            initialDateInt = firstDateInt;
          }
          if (lastDateInt.data < _detailStartDateInt.data) {
            initialDateInt = lastDateInt;
          }
        }

        final newDate = await showDatePicker(
          context: context,
          initialDate: initialDateInt.dt,
          firstDate: firstDateInt.dt,
          lastDate: lastDateInt.dt,
        );
        if (null != newDate) {
          _updateDetailStartDateInt(DateInt(newDate));
          await _excelMgr.prepareDetailData(_detailStartDateInt);
          _refreshDetailListFirstShowPos(_excelMgr);
          setState(() {});
        }
      },
    );
  }

  Widget _buildEndDateButton() {
    return GestureDetector(
      child: FittedBox(
          child: Card(
        color: Colors.lightBlueAccent,
        child: Container(
          alignment: Alignment.center,
          child: FittedBox(
            child: Text(
              "截止显示日期：" + _selectedDetailEndDateText,
              style: TextStyle(fontSize: _width / 14),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      )),
      onTap: () async {
        final period = _excelMgr.getDetailDatePeriod();
        assert(null != period);

        DateInt firstDateInt;
        DateInt lastDateInt;
        DateInt initialDateInt;
        if (null == period) {
          DateInt todayInt = DateInt(DateTime.now());
          firstDateInt = todayInt;
          lastDateInt = todayInt;
          initialDateInt = todayInt;
        } else {
          firstDateInt = period[0];
          lastDateInt = period[1];
          initialDateInt = _selectedDetailEndDateInt;

          if (_detailStartDateInt.data < firstDateInt.data) {
            initialDateInt = firstDateInt;
          }
          if (lastDateInt.data < _detailStartDateInt.data) {
            initialDateInt = lastDateInt;
          }
        }

        final newDate = await showDatePicker(
          context: context,
          initialDate: initialDateInt.dt,
          firstDate: firstDateInt.dt,
          lastDate: lastDateInt.dt,
        );
        if (null != newDate) {
          _updateSelectedDetailEndDateInt(DateInt(newDate));

          setState(() {});
        }
      },
    );
  }

  _refreshDetailListFirstShowPos(ExcelMgr mgr) {
//    if (_selectedDetailEndDateInt.data < _detailStartDateInt.data) {
//      _detailListFirstShowPos = null;
//      return;
//    }
    int index = mgr.detailList.length - 1;
    for (; 0 <= index; index--) {
      if (mgr.detailList[index].commitDateInt.data < _detailStartDateInt.data) {
        break;
      }
    }

    _detailListFirstShowPos =
        (index + 1 < mgr.detailList.length) ? (index + 1) : null;

    return;
  }

  String _text;
  Widget _buildContent() {
    if (null == _detailListFirstShowPos) {
      return Container(
          child: Text("暂无新增名单",
              style: TextStyle(fontSize: _width / 10, color: Colors.red)));
    }

    if (_excelMgr.detailList.isEmpty) {
      return Container(
          child: Text("暂无随喜记录",
              style: TextStyle(fontSize: _width / 10, color: Colors.red)));
    }

    _assembleText();

    return Expanded(
        child: Scrollbar(
            child: SingleChildScrollView(
      child: Card(
        color: Colors.grey[200],
        child: Text(
          _text,
          style: TextStyle(fontSize: _width / 15),
        ),
      ),
    )));
  }

  void _assembleText() {
    final first = _excelMgr.detailList[_detailListFirstShowPos];
    int lastDate = first.commitDateInt.data;

    _text = formatDateInt(first.commitDateInt) + "\t";

    int index;
    for (index = _detailListFirstShowPos;
        index < _excelMgr.detailList.length;
        index++) {
      final item = _excelMgr.detailList[index];
      if (_selectedDetailEndDateInt.data < item.commitDateInt.data) {
        break;
      }

      if (lastDate != item.commitDateInt.data) {
        lastDate = item.commitDateInt.data;
        _text += "\n" + formatDateInt(item.commitDateInt) + "\t " + item.name;
      } else {
        _text += " " + item.name;
      }
    }

    _actualDetailEndDate = _excelMgr.detailList[index - 1].commitDateInt.data;

    return;
  }
}

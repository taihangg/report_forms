import 'dart:io';
import 'dart:ui';
import 'add_expenditure_data_page.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';
import 'file_storage.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';
import 'package:path_provider/path_provider.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:directory_picker/directory_picker.dart';

import 'package:esys_flutter_share/esys_flutter_share.dart'
    as esys_flutter_share;

import 'common_util.dart';

class ExcelMgr {
  static KeyValueFile _KVFile = KeyValueFile();
  final String _dirKey = "directoryKey";
  final String _fileName = "供灯统计数据表.xlsx";

  static Directory _dir;
  String get path {
    if (null != _dir) {
      return _dir.path;
    }
  }

  String get dataFileFullPath => path + "/" + _fileName;

  static String _status = "default";
  bool get ready => ("ok" == _status);

  static File _file;
  static SpreadsheetDecoder _decoder;
  final String _detailTableName = "随喜与名单记录";
  final List<String> _detailTableTitles = ["提交者", "提交时间", "姓名", "金额（单位：元）"];
  final String _statisticsTableName = "统计";
  final List<String> _statisticsTableTitles = [
    "序号",
    "日期",
    "当日随喜",
    "累计随喜",
    "当日支出",
    "累计支出",
    "剩余"
  ];
  final String _expenditureListTableName = "采购清单";
  final List<String> _expenditureListTableTitles = [
    "序号",
    "日期",
    "物品",
    "说明",
    "单价",
    "数量",
    "总价",
    "运费",
    "折扣",
    "实价"
  ];
  final String _nameListTableName = "打印名单";
  final List<String> _nameListTableTitles = ["日期", "名单"];

  // Map<date,data>
  static Map<int, List<StatisticsDailyDataItem>> _statisticsDailyDataMap = {};
  static List<StatisticsDailyDataItem> _statisticsDailyDataList = [];
  List<StatisticsDailyDataItem> get statisticsDailyDataList =>
      _statisticsDailyDataList;
  static int _lastDate = 0;

  static Map<int, double> _dailyExpenditureDataMap = {}; // Map<date,money>
  static List<ExpenditureDataItem> _expenditureDataItemList = [];
  List<ExpenditureDataItem> get expenditureDataItemList =>
      _expenditureDataItemList;

  static List<DetailItem> _detailList = [];
  List<DetailItem> get detailList => _detailList;
  DetailItem get lastDetailItem {
    if (_detailList.isNotEmpty) {
      return _detailList.last;
    }
  }

  final void Function(bool ok, String msg) onFinishedFn;

  ExcelMgr({this.onFinishedFn}) {
    _init();
  }

  void _init() async {
    if (ready) {
      if (null != onFinishedFn) {
        onFinishedFn(true, null);
      }
      return;
    }
    if ("default" != _status) {
      return;
    }
    _status = "initing";

    if (null == _dir) {
      String path = await _KVFile.getString(key: _dirKey);
      if (null != path) {
        _dir = Directory(path);
      } else {
        _dir = await _defaultExportDirectory();
      }
    }

    if (null == _file) {
      _file = File(_dir.path + "/" + _fileName);
    }

    if (null == _decoder) {
      if (!await _file.exists()) {
        _decoder = await _createInitFile(_file);
        if (null == _decoder) {
          final msg = "初始化文件目录失败，请修改app读写存储的权限";
          if (null != onFinishedFn) {
            onFinishedFn(false, msg);
          }
          return;
        }
      } else {
        try {
          List<int> bytes = _file.readAsBytesSync();
          _decoder = SpreadsheetDecoder.decodeBytes(bytes, update: true);
        } catch (err) {
          final msg = "请使用合法的xlsx文件";
          if (null != onFinishedFn) {
            onFinishedFn(false, msg);
          }
          return;
        }
        await _readExpenditureTable();
        await _readStatisticsTable();
        await _readDetailTable();

        await _checkOut();
      }
      _status = "ok";
    }

    if (null != onFinishedFn) {
      onFinishedFn(ready, null);
    }

    return null;
  }

  Future<ByteData> _loadAssetFile() async {
    final assetPath = "assets/files/empty.xlsx";
    return await rootBundle.load(assetPath);
  }

  Future<Directory> _defaultExportDirectory() async {
    Directory dir;

    if (defaultTargetPlatform == TargetPlatform.android) {
//      dir = await getExternalStorageDirectory();
      dir = Directory("/storage/emulated/0/供灯报表数据");
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      dir = await getApplicationDocumentsDirectory();
    }

    return dir;
  }

  Future<SpreadsheetDecoder> _createInitFile(File file) async {
    ByteData _bd = await _loadAssetFile();
    SpreadsheetDecoder decoder = SpreadsheetDecoder.decodeBytes(
        _bd.buffer.asUint8List().toList(),
        update: true);

    _setAllTablesDetailTitle(decoder);

    try {
      await file.create(recursive: true);
    } catch (err) {
      return null;
    }
    await file.writeAsBytes(decoder.encode(), flush: true);

    return decoder;
  }

  _setAllTablesDetailTitle(SpreadsheetDecoder decoder) {
    _setTableDetailTitle(decoder, _detailTableName, _detailTableTitles);
    _setTableDetailTitle(decoder, _statisticsTableName, _statisticsTableTitles);
    _setTableDetailTitle(
        decoder, _expenditureListTableName, _expenditureListTableTitles);
    _setTableDetailTitle(decoder, _nameListTableName, _nameListTableTitles);

    return;
  }

  _setTableDetailTitle(
      SpreadsheetDecoder decoder, String tableName, List<String> titleList) {
    decoder.insertRow(tableName, 0);
    for (int i = 0; i < titleList.length; i++) {
      decoder.insertColumn(tableName, i);
      decoder.updateCell(tableName, i, 0, titleList[i]);
    }
  }

  _readExpenditureTable() async {
    final expenditureTable = _decoder.tables[_expenditureListTableName];
    for (int r = 1; r < expenditureTable.maxRows; r++) {
      final item = await ExpenditureDataItem();

      item.ID = _parseInt(expenditureTable.rows[r][0]);
      if (null == item.ID) {
        final msg = "解析 ${_expenditureListTableName}[$r][0] 失败.";
        print(msg);
        item.ID = _expenditureDataItemList.length;
      }

      item.dateInt = parseExcelDate(expenditureTable.rows[r][1]);
      if (null == item.dateInt) {
        final msg = "解析 ${_expenditureListTableName}[$r][1] 失败.";
        print(msg);
        continue;
      }

      item.name = expenditureTable.rows[r][2];
      item.comment = expenditureTable.rows[r][3];

      item.price = _parseDouble(expenditureTable.rows[r][4]);
      if (null == item.price) {
        final msg = "解析 ${_expenditureListTableName}[$r][4] 失败.";
        print(msg);
        continue;
      }

      item.count = _parseInt(expenditureTable.rows[r][5]);
      if (null == item.count) {
        final msg = "解析 ${_expenditureListTableName}[$r][5] 失败.";
        print(msg);
        continue;
      }

      item.totalPrice = _parseDouble(expenditureTable.rows[r][6]);
      if (null == item.totalPrice) {
        final msg = "解析 ${_expenditureListTableName}[$r][6] 失败.";
        print(msg);
        continue;
      }

      item.transportationExpense = _parseDouble(expenditureTable.rows[r][7]);
      item.discount = _parseDouble(expenditureTable.rows[r][8]);

      item.finalMoney = _parseDouble(expenditureTable.rows[r][9]);
      if (null == item.finalMoney) {
        final msg = "解析 ${_expenditureListTableName}[$r][9] 失败.";
        print(msg);
        continue;
      }

      _expenditureDataItemList.add(item);
      _dailyExpenditureDataMap.update(item.dateInt.data, (double oldValue) {
        return oldValue + item.finalMoney;
      }, ifAbsent: () {
        return item.finalMoney;
      });
    }

    return;
  }

  _readStatisticsTable() async {
    bool needResort = false;
    final statisticsTable = _decoder.tables[_statisticsTableName];
    for (int r = 1; r < statisticsTable.maxRows; r++) {
      final item = await StatisticsDailyDataItem();

      item.rowIndex = r;
      item.dateInt = parseExcelDate(statisticsTable.rows[r][1]);
      if (null == item.dateInt) {
        final msg = "解析 ${_expenditureListTableName}[$r][1] 失败.";
        print(msg);
        continue;
      }
      item.dailyIncomeMoney = _parseDouble(statisticsTable.rows[r][2]) ?? 0;
      item.sumIncomeMoney = _parseDouble(statisticsTable.rows[r][3]) ?? 0;
      item.dailyExpenditureMoney = _parseDouble(statisticsTable.rows[r][4]);
      item.sumExpenditureMoney = _parseDouble(statisticsTable.rows[r][5]) ?? 0;
      item.leftMoney = _parseDouble(statisticsTable.rows[r][6]) ?? 0;

      _statisticsDailyDataList.add(item);
      _statisticsDailyDataMap.update(
        item.dateInt.data,
        (list) {
          list.add(item);
          return list;
        },
        ifAbsent: () {
          return [item];
        },
      );

      if (_lastDate < item.dateInt.data) {
        _lastDate = item.dateInt.data;
      } else {
        needResort = true;
//        assert(false); // 未处理
        // TODO do some thing
      }
    }
    if (needResort) {
//      _dailyDataList.sort(DailyDataItem.sortAsc);
      // TODO flush to file
    }

    int i = 0;
    for (final item in _statisticsDailyDataList) {
      item.pos = i++;
    }

    return;
  }

  _readDetailTable() async {
    final table = _decoder.tables[_detailTableName];
    for (int r = table.maxRows - 1; 0 < r; r--) {
      final item = await DetailItem();
      item.rowIndex = r;
      item.commitTime = table.rows[r][1];
      item.commitDateInt = parseExcelDate(item.commitTime);
      if (null == item.commitDateInt) {
        final msg = "解析 ${_expenditureListTableName}[$r][0] 失败.";
        print(msg);
//        continue;
      }

      item.name = table.rows[r][2];
      item.money = table.rows[r][3];
      _detailList.add(item);
    }

    _detailList = _detailList.reversed.toList();

    return;
  }

  double _parseDouble(dynamic v) {
    if (null != v) {
      switch (v.runtimeType) {
        case String:
          {
            try {
              double d = double.parse(v);
              return d;
            } catch (err) {}
            break;
          }
        case double:
          {
            return v;
            break;
          }
        case int:
          {
            return v;
            break;
          }
        default:
          {
            assert(false);
            break;
          }
      }
    }
    return null;
  }

  int _parseInt(dynamic v) {
    if (null != v) {
      switch (v.runtimeType) {
        case String:
          {
            try {
              int i = int.parse(v);
              return i;
            } catch (err) {}
            break;
          }
        case double:
          {
            return v.toInt();
            break;
          }
        case int:
          {
            return v;
            break;
          }
        default:
          {
            assert(false);
            break;
          }
      }
    }
    return null;
  }

  Future<void> AddDetailData(List<List<String>> lines) async {
    int i = 0;
    while (!ready) {
      await Future.delayed(Duration(seconds: 1));
      i++;
      if (5 < i) {
        return;
      }
    }

    List<StatisticsDailyDataItem> datas = _parseStatisticsDailyData(lines);

    _addDetailDataToDetailTable(lines, datas);

    _updateStatisticsDataToStatisticsTable(datas);
    _updateNameListToTable(datas);

    await _file.writeAsBytes(_decoder.encode(), flush: true);

    return;
  }

  _addDetailDataToDetailTable(
      List<List<String>> lines, List<StatisticsDailyDataItem> datas) {
    final table = _decoder.tables[_detailTableName];
    for (final line in lines) {
      final item = DetailItem();

      item.rowIndex = table.maxRows;
      item.commitTime = line[1];
      item.commitDateInt = parseExcelDate(item.commitTime);
      item.name = line[2];
      item.money = line[3];

      _detailList.add(item);

      _decoder.insertRow(_detailTableName, item.rowIndex);
      for (int i = 0; i < line.length; i++) {
        _decoder.updateCell(_detailTableName, i, item.rowIndex, line[i]);
      }
    }
    return;
  }

  List<StatisticsDailyDataItem> _parseStatisticsDailyData(
      List<List<String>> lines) {
    Map<int, StatisticsDailyDataItem> datas = {};

    for (final line in lines) {
      final daily = StatisticsDailyDataItem();

      daily.dateInt = parseExcelDate(line[1]);
      assert(null != daily.dateInt);

      daily.nameText = line[2] ?? "";
      daily.dailyIncomeMoney = 0; // 默认0
      if ((null != line[3]) && ("" != line[3])) {
        try {
          daily.dailyIncomeMoney = double.parse(line[3]);
        } catch (err) {
          assert(false);
        }
      }
      datas.update(
        daily.dateInt.data,
        (v) {
          v.nameText += " " + daily.nameText;
          v.dailyIncomeMoney += daily.dailyIncomeMoney;
          return v;
        },
        ifAbsent: () {
//          daily.dailyExpenditureMoney = 0;
          daily.sumExpenditureMoney = 0;
          return daily;
        },
      );
    }
    return datas.values.toList()..sort(StatisticsDailyDataItem.sortByDateAsc);
  }

  _updateStatisticsDataToStatisticsTable(List<StatisticsDailyDataItem> datas) {
    // 接到_statisticsDailyDataList的尾部
    for (final StatisticsDailyDataItem v in datas) {
      if (_statisticsDailyDataList.isNotEmpty) {
        final last = _statisticsDailyDataList.last;
        if (last.dateInt.data == v.dateInt.data) {
          // 当前第一条与历史最后一条日期相同，需要合并
          if (0 != v.dailyIncomeMoney) {
            last.dailyIncomeMoney = last.dailyIncomeMoney + v.dailyIncomeMoney;
            last.sumIncomeMoney = last.sumIncomeMoney + v.dailyIncomeMoney;
            last.leftMoney = last.leftMoney + v.dailyIncomeMoney;

            _flushStatisticsItemToDecoder(last); // 更新文件
          }
        } else {
          // 新增
          v.sumIncomeMoney = last.sumIncomeMoney + v.dailyIncomeMoney;
          v.sumExpenditureMoney = last.sumExpenditureMoney;
          v.leftMoney = last.leftMoney + v.dailyIncomeMoney;

//          v.rowIndex = _statisticsDailyDataList.length + 1;

          _statisticsDailyDataList.add(v);
          _flushStatisticsItemToDecoder(v); // 更新文件
        }
      } else {
        // 第一条
//        v.rowIndex = _statisticsDailyDataList.length + 1;
        v.sumIncomeMoney = v.dailyIncomeMoney;
        v.leftMoney = v.dailyIncomeMoney;
        _statisticsDailyDataList.add(v);
        _flushStatisticsItemToDecoder(v); // 更新文件
      }
    }

    return;
  }

  _flushStatisticsItemToDecoder(StatisticsDailyDataItem v) {
    final table = _decoder.tables[_statisticsTableName];
    if (null == v.rowIndex) {
      v.rowIndex = table.maxRows;
      _decoder.insertRow(_statisticsTableName, v.rowIndex);
    } else {
      assert(v.rowIndex < table.maxRows);
    }

    _decoder.updateCell(_statisticsTableName, 0, v.rowIndex, v.rowIndex);
    _decoder.updateCell(
        _statisticsTableName, 1, v.rowIndex, _formatDateInt(v.dateInt));

    if (null != v.dailyIncomeMoney) {
      _decoder.updateCell(_statisticsTableName, 2, v.rowIndex,
          v.dailyIncomeMoney.toStringAsFixed(2));
    }
    if (null != v.sumIncomeMoney) {
      _decoder.updateCell(_statisticsTableName, 3, v.rowIndex,
          v.sumIncomeMoney.toStringAsFixed(2));
    }
    if (null != v.dailyExpenditureMoney) {
      _decoder.updateCell(_statisticsTableName, 4, v.rowIndex,
          v.dailyExpenditureMoney.toStringAsFixed(2));
    }
    if (null != v.sumExpenditureMoney) {
      _decoder.updateCell(_statisticsTableName, 5, v.rowIndex,
          v.sumExpenditureMoney.toStringAsFixed(2));
    }
    _decoder.updateCell(
        _statisticsTableName, 6, v.rowIndex, v.leftMoney.toStringAsFixed(2));

    return;
  }

  _updateNameListToTable(List<StatisticsDailyDataItem> datas) {
    final table = _decoder.tables[_nameListTableName];
    for (final v in datas) {
      // TODO 如果最后日期相同，要合并
      final rowIndex = table.maxRows;
      _decoder.insertRow(_nameListTableName, rowIndex);
      _decoder.updateCell(
          _nameListTableName, 0, rowIndex, _formatDateInt(v.dateInt));
      _decoder.updateCell(_nameListTableName, 1, rowIndex, v.nameText);
    }
  }

  String get summary {
    DateInt dateInt = DateInt(DateTime.now());
    double sumIncomeMoney = 0;
    double sumExpenditureMoney = 0;
    double leftMoney = 0;
    if (_statisticsDailyDataList.isNotEmpty) {
      final last = _statisticsDailyDataList.last;
      dateInt = last.dateInt;
      sumIncomeMoney = last.sumIncomeMoney;
      sumExpenditureMoney = last.sumExpenditureMoney;
      leftMoney = last.leftMoney;
    }
    return """【义工组汇报】
截止[${dateInt.year}年${dateInt.month}月${dateInt.day}日23点59分]，
共收到药师七佛灯随喜善款:
共计:${sumIncomeMoney.toStringAsFixed(2)}元
支出:${sumExpenditureMoney.toStringAsFixed(2)}元
结余:${leftMoney.toStringAsFixed(2)}元
请大家审核！随喜功德！
如有错漏请及时告诉我。感谢大家的支持和发心。祝愿大家获得药师七佛的加持护佑、健康长寿、衣食丰足、无疾除恶、福慧俱足、得生净土！""";
  }

  void AddExpenditureDataTable(ExpenditureDataItem expenditure) {
    _updateExpenditureDataToExpenditureTable(expenditure);

    _updateExpenditureMoneyToStatisticsTable2(
        expenditure.dateInt, expenditure.finalMoney);

    _file.writeAsBytes(_decoder.encode(), flush: true);

    return;
  }

  _updateExpenditureDataToExpenditureTable(ExpenditureDataItem expenditure) {
    expenditure.ID = _expenditureDataItemList.length + 1;

    _expenditureDataItemList.add(expenditure);

    _dailyExpenditureDataMap.update(expenditure.dateInt.data,
        (double oldValue) {
      return oldValue + expenditure.finalMoney;
    }, ifAbsent: () {
      return expenditure.finalMoney;
    });

    final table = _decoder.tables[_expenditureListTableName];
    final int r = table.maxRows;
    _decoder.insertRow(_expenditureListTableName, r);
    _decoder.updateCell(_expenditureListTableName, 0, r, expenditure.ID);
    _decoder.updateCell(
        _expenditureListTableName, 1, r, _formatDateInt(expenditure.dateInt));
    _decoder.updateCell(_expenditureListTableName, 2, r, expenditure.name);
    if (null != expenditure.comment) {
      _decoder.updateCell(_expenditureListTableName, 3, r, expenditure.comment);
    }
    _decoder.updateCell(
        _expenditureListTableName, 4, r, expenditure.price.toStringAsFixed(2));
    _decoder.updateCell(_expenditureListTableName, 5, r, expenditure.count);
    _decoder.updateCell(_expenditureListTableName, 6, r,
        expenditure.totalPrice.toStringAsFixed(2));
    if (null != expenditure.transportationExpense) {
      _decoder.updateCell(_expenditureListTableName, 7, r,
          expenditure.transportationExpense.toStringAsFixed(2));
    }
    if (null != expenditure.discount) {
      _decoder.updateCell(_expenditureListTableName, 8, r,
          expenditure.discount.toStringAsFixed(2));
    }
    _decoder.updateCell(_expenditureListTableName, 9, r,
        expenditure.finalMoney.toStringAsFixed(2));

    return;
  }

//  _updateExpenditureMoneyToStatisticsTable(DateInt dateInt, double money) {
//    String type;
//    // 倒着找位置
//    int pos = _statisticsDailyDataList.length - 1;
//    for (final item in _statisticsDailyDataList.reversed) {
//      if (item.dateInt.data == dateInt.data) {
//        type = "exist";
//
//        item.dailyExpenditureMoney = (item.dailyExpenditureMoney ?? 0) + money;
//        item.sumExpenditureMoney = (item.sumExpenditureMoney ?? 0) + money;
//        item.leftMoney -= money;
//
//        _flushStatisticsItemToDecoder(item);
//
//        break;
//      } else if (item.dateInt.data < dateInt.data) {
//        // 遇到第一个小的日期，就插入到其后的位置
//        type = "addNew";
//        final newItem = StatisticsDailyDataItem();
//
//        newItem.dateInt = dateInt;
//        newItem.dailyIncomeMoney = 0;
//        newItem.dailyExpenditureMoney = money;
//
//        newItem.sumIncomeMoney = item.sumIncomeMoney;
//        newItem.sumExpenditureMoney = item.sumExpenditureMoney + money;
//        newItem.leftMoney = item.leftMoney - money;
//        newItem.rowIndex = item.rowIndex + 1;
//
//        _statisticsDailyDataList.insert(pos + 1, newItem); // 插入到当前值得后面
//        _testShowDate();
//        _decoder.insertRow(_statisticsTableName, newItem.rowIndex);
//        _flushStatisticsItemToDecoder(newItem);
//
//        pos++; // 跳过当前位置
//        break;
//      }
//      pos--;
//    }
//
//    // 可能这就是最小的日期
//    if (null == type) {
//      pos = 0;
//      type = "addNew";
//      final newItem = StatisticsDailyDataItem();
//      newItem.rowIndex = 1;
//      newItem.dateInt = dateInt;
//      newItem.sumIncomeMoney = 0;
//      newItem.dailyExpenditureMoney = money;
//      newItem.sumExpenditureMoney = money;
//      newItem.leftMoney = -money;
//
//      _statisticsDailyDataList.insert(pos, newItem);
//      _decoder.insertRow(_statisticsTableName, newItem.rowIndex);
//      _flushStatisticsItemToDecoder(newItem);
//    }
//
//    if ("addNew" == type) {
//      // 更新后面部分的rowIndex
//      for (int i = pos + 1; i < _statisticsDailyDataList.length; i++) {
//        final item = _statisticsDailyDataList[i];
//        item.rowIndex++;
//      }
//    }
//
//    // 更新后面部分的累计金额
//    for (int i = pos + 1; i < _statisticsDailyDataList.length; i++) {
//      final item = _statisticsDailyDataList[i];
//      item.sumExpenditureMoney += money;
//      item.leftMoney -= money;
//
//      _decoder.updateCell(_statisticsTableName, 5, item.rowIndex,
//          item.sumExpenditureMoney.toStringAsFixed(2));
//      _decoder.updateCell(_statisticsTableName, 6, item.rowIndex,
//          item.leftMoney.toStringAsFixed(2));
//    }
//
//    return;
//  }

  _updateExpenditureMoneyToStatisticsTable2(DateInt dateInt, double money) {
    String type;
    int pos;

    _statisticsDailyDataMap.update(
      dateInt.data,
      (list) {
        type = "exist";

        final StatisticsDailyDataItem item = list.last;

        item.dailyExpenditureMoney = (item.dailyExpenditureMoney ?? 0) + money;
        item.sumExpenditureMoney = (item.sumExpenditureMoney ?? 0) + money;
        item.leftMoney -= money;

        _flushStatisticsItemToDecoder(item);

        pos = item.pos;

        return list;
      },
      ifAbsent: () {
        type = "addNew";

        final newItem = StatisticsDailyDataItem();

        // 倒着找位置
//        pos = _statisticsDailyDataList.length - 1;
        for (final item in _statisticsDailyDataList.reversed) {
          if (item.dateInt.data == dateInt.data) {
            assert(false);
          } else if (item.dateInt.data < dateInt.data) {
            // 遇到第一个小的日期，就插入到其后的位置
//            type = "addNew";
//            final newItem = StatisticsDailyDataItem();

            newItem.dateInt = dateInt;
            newItem.dailyIncomeMoney = 0;
            newItem.dailyExpenditureMoney = money;

            newItem.sumIncomeMoney = item.sumIncomeMoney;
            newItem.sumExpenditureMoney = item.sumExpenditureMoney + money;
            newItem.leftMoney = item.leftMoney - money;
            newItem.rowIndex = item.rowIndex + 1;
            newItem.pos = item.pos + 1;

            _statisticsDailyDataList.insert(newItem.pos, newItem); // 插入到当前值得后面
            _decoder.insertRow(_statisticsTableName, newItem.rowIndex);
            _flushStatisticsItemToDecoder(newItem);

            pos = item.pos + 1; // 跳过当前位置
            break;
          }
//          pos--;
        }

        // 可能这就是最小的日期
        if (null == type) {
          pos = 0;
          type = "addNew";
          final newItem = StatisticsDailyDataItem();
          newItem.rowIndex = 1;
          newItem.dateInt = dateInt;
          newItem.sumIncomeMoney = 0;
          newItem.dailyExpenditureMoney = money;
          newItem.sumExpenditureMoney = money;
          newItem.leftMoney = -money;

          _statisticsDailyDataList.insert(pos, newItem);
          _decoder.insertRow(_statisticsTableName, newItem.rowIndex);
          _flushStatisticsItemToDecoder(newItem);
        }

        if ("addNew" == type) {
          // 更新后面部分的rowIndex
          for (int i = pos + 1; i < _statisticsDailyDataList.length; i++) {
            final item = _statisticsDailyDataList[i];
            item.rowIndex++;
            item.pos++;
          }
        }

        return [newItem];
      },
    );

    // 更新后面部分的累计金额
    for (int i = pos + 1; i < _statisticsDailyDataList.length; i++) {
      final item = _statisticsDailyDataList[i];
      item.sumExpenditureMoney += money;
      item.leftMoney -= money;

      _decoder.updateCell(_statisticsTableName, 5, item.rowIndex,
          item.sumExpenditureMoney.toStringAsFixed(2));
      _decoder.updateCell(_statisticsTableName, 6, item.rowIndex,
          item.leftMoney.toStringAsFixed(2));
    }

    return;
  }

  _formatDateInt(DateInt v) {
    return "${v.year}/${v.month}/${v.day}";
  }

  _checkOut() async {
    bool modified = false;
    int minPos;
    String type;
    int testLimit = 0;
    for (final entry in _dailyExpenditureDataMap.entries) {
      int date = entry.key;
      double money = entry.value;
      await testLimit++;
      if (2 < testLimit) {
//        return;
      }

      _statisticsDailyDataMap.update(
        date,
        (list) {
          bool hasSame = false;
          for (final item in list.reversed) {
            if (money == item.dailyExpenditureMoney) {
              hasSame = true;
              break;
            }
          }

          if (!hasSame) {
            type = "update";
            StatisticsDailyDataItem curItem = list.last;

            if ((null == minPos) || (curItem.pos < minPos)) {
              minPos = curItem.pos;
            }
            modified = true;

            curItem.dailyExpenditureMoney = money;
            if (0 == curItem.pos) {
              curItem.sumExpenditureMoney = curItem.dailyExpenditureMoney;
            } else {
              final last = _statisticsDailyDataList[curItem.pos - 1];
              curItem.sumExpenditureMoney =
                  last.sumExpenditureMoney + curItem.dailyExpenditureMoney;
            }
            curItem.leftMoney =
                curItem.sumIncomeMoney - curItem.sumExpenditureMoney;

            _decoder.updateCell(_statisticsTableName, 4, curItem.rowIndex,
                curItem.dailyExpenditureMoney.toStringAsFixed(2));
            _decoder.updateCell(_statisticsTableName, 5, curItem.rowIndex,
                curItem.sumExpenditureMoney.toStringAsFixed(2));
            _decoder.updateCell(_statisticsTableName, 6, curItem.rowIndex,
                curItem.leftMoney.toStringAsFixed(2));
          }

          return list;
        },
        ifAbsent: () {
          final newItem = StatisticsDailyDataItem();
          modified = true;
          type = null;

          for (final item in _statisticsDailyDataList.reversed) {
            if (item.dateInt.data == date) {
              assert(false);
            } else if (item.dateInt.data < date) {
              // 加到当前值得下一个
              type = "addNew";

              newItem.pos = item.pos + 1;
              newItem.dailyIncomeMoney = 0;
              newItem.dailyExpenditureMoney = money;
              newItem.rowIndex = item.pos + 1;
              newItem.sumIncomeMoney = item.sumIncomeMoney;
              newItem.sumExpenditureMoney = item.sumExpenditureMoney + money;

              newItem.leftMoney =
                  newItem.sumIncomeMoney - newItem.sumExpenditureMoney;
              newItem.dateInt = DateInt.fromInt(date);
              _statisticsDailyDataList.insert(newItem.pos, newItem);
//              _testShowDate(_statisticsDailyDataList[newItem.pos]);

              newItem.rowIndex = newItem.pos + 1;
              _decoder.insertRow(_statisticsTableName, newItem.rowIndex);
              _flushStatisticsItemToDecoder(newItem);

              if ((null == minPos) || (newItem.pos < minPos)) {
                minPos = newItem.pos;
              }

              break;
            }
          }

          if (null == type) {
            // 添加到第0位
            type = "addNew";
            modified = true;

            newItem.pos = 0;
            newItem.dailyIncomeMoney = 0;
            newItem.dailyExpenditureMoney = money;

            newItem.sumIncomeMoney = 0;
            newItem.sumExpenditureMoney = money;

            newItem.leftMoney =
                newItem.sumIncomeMoney - newItem.sumExpenditureMoney;

            newItem.dateInt = DateInt.fromInt(date);
            _statisticsDailyDataList.insert(newItem.pos, newItem);
//            _testShowDate(_statisticsDailyDataList[newItem.pos]);

            newItem.rowIndex = 1;
            _decoder.insertRow(_statisticsTableName, newItem.rowIndex);
            _flushStatisticsItemToDecoder(newItem);

            minPos = 0;
          }

          if ("addNew" == type) {
            assert(modified);
            // 更新后面的rowIndex和pos
            StatisticsDailyDataItem last = _statisticsDailyDataList[minPos];
            for (int i = minPos + 1; i < _statisticsDailyDataList.length; i++) {
              final item = _statisticsDailyDataList[i];
              item.pos = i;

              item.rowIndex++;
              _decoder.updateCell(
                  _statisticsTableName, 0, item.rowIndex, item.rowIndex);

              item.sumExpenditureMoney =
                  last.sumExpenditureMoney + (item.dailyExpenditureMoney ?? 0);
              _decoder.updateCell(_statisticsTableName, 5, item.rowIndex,
                  item.sumExpenditureMoney.toStringAsFixed(2));

              item.leftMoney = item.sumIncomeMoney - item.sumExpenditureMoney;
              _decoder.updateCell(_statisticsTableName, 6, item.rowIndex,
                  item.leftMoney.toStringAsFixed(2));

              last = item;
            }
//            _testShowDate(_statisticsDailyDataList[pos]);

          }

          return [newItem];
        },
      );
    }

    if (modified) {
      // 从新计算剩下部分的 "总支出" 与 "剩余"
      StatisticsDailyDataItem last;
      if (0 == minPos) {
        last = StatisticsDailyDataItem();
        last.sumExpenditureMoney = 0;
      } else {
        last = _statisticsDailyDataList[minPos];
      }
      for (int i = minPos + 1; i < _statisticsDailyDataList.length; i++) {
        final item = _statisticsDailyDataList[i];
        item.sumExpenditureMoney =
            last.sumExpenditureMoney + (item.dailyExpenditureMoney ?? 0);
        item.leftMoney = item.sumIncomeMoney - item.sumExpenditureMoney;
        _decoder.updateCell(_statisticsTableName, 5, item.rowIndex,
            item.sumExpenditureMoney.toStringAsFixed(2));
        _decoder.updateCell(_statisticsTableName, 6, item.rowIndex,
            item.leftMoney.toStringAsFixed(2));

        last = item;
      }

      await _file.writeAsBytes(_decoder.encode(), flush: true);
    }

    return;
  }

//  _testShowDate(StatisticsDailyDataItem cur) {
//    String msg = "${cur.dateInt.data}\t[";
//    int i = 0;
//    for (final item in _statisticsDailyDataList) {
////      assert(i == item.pos);
//      msg += "${item.dateInt.data}:${item.pos},";
//      i++;
//    }
//    msg += "]\n";
//    print(msg);
//  }
}

class StatisticsDailyDataItem {
  int pos;
  int rowIndex;
  DateInt dateInt;
  double dailyIncomeMoney;
  double sumIncomeMoney;
  double dailyExpenditureMoney;
  double sumExpenditureMoney;
  double leftMoney;
  String nameText;

  static int sortByDateAsc(
      StatisticsDailyDataItem a, StatisticsDailyDataItem b) {
    if (a.dateInt.data < b.dateInt.data) {
      return -1;
    } else if (a.dateInt.data == b.dateInt.data) {
      return 0;
    } else {
      return 1;
    }
  }
}

class ExpenditureDataItem {
  int ID;
  DateInt dateInt;
  String name;
  String comment;
  double price;
  int count;
  double totalPrice;
  double transportationExpense;
  double discount;
  double finalMoney;
}

class DetailItem {
  int rowIndex;
  String commitTime;
  DateInt commitDateInt;
  String name;
  String money;
}

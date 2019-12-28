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

typedef _OnFinishedFn = void Function(ExcelMgr mgr, bool ok, String errMsg);

class ExcelMgr {
  final int latestDetailDataDayCount; // 首次读取的detail数据的天数
  final _OnFinishedFn onUpdatedFn;
  ExcelMgr({this.latestDetailDataDayCount = 15, this.onUpdatedFn}) {
    _initAndNotify();
  }

  _initAndNotify() async {
    await _init();
    if (null != onUpdatedFn) {
      _fnList.add(onUpdatedFn);
      onUpdatedFn(this, ready, _errMsg);
    }
  }

  static List<_OnFinishedFn> _fnList = [];

  void cancelNotify() {
    _fnList.remove(onUpdatedFn);
  }

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

// Map<date,List<data>>
  static Map<int, List<DailyDataItem>> _statisticsDailyDataMap = {};
  static List<DailyDataItem> _statisticsDailyDataList = [];
  List<DailyDataItem> get statisticsDailyDataList => _statisticsDailyDataList;

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

  static String _errMsg;

  void _init() async {
    if (ready) {
      return;
    }

    if (("default" != _status) && ("error" != _status)) {
      return;
    }

    _status = "initing";

    _dir = await _defaultExportDirectory();

    _file = File(_dir.path + "/" + _fileName);

    if (!await _file.exists()) {
      // 不存在就用模板创建
      _decoder = await _createInitFile(_file);
      if (null == _decoder) {
        _status = "error";
        _errMsg = "初始化文件目录失败，请修改app读写存储的权限";
        return;
      } else {
        // 新建的模板，没有数据，不需要解析，直接返回
        _status = "ok";
        return;
      }
    }

    // 存在就读取、解析

    try {
      List<int> bytes = _file.readAsBytesSync();
      _decoder = SpreadsheetDecoder.decodeBytes(bytes, update: true);
    } catch (err) {
      _status = "error";
      _errMsg = "请使用合法的xlsx文件";

      return;
    }

    _errMsg = "";

    _expenditureDataItemList = [];
    String errMsgExpenditure = _readExpenditureTable(
        _decoder.tables[_expenditureListTableName], _expenditureDataItemList);
    _errMsg += (errMsgExpenditure ?? "");

    _dailyExpenditureDataMap =
        _transformExpenditureDataToDailyMap(_expenditureDataItemList);

    _statisticsDailyDataList = [];
    String errMsgStatistics = _readStatisticsTable(
        _decoder.tables[_statisticsTableName], _statisticsDailyDataList);
    _errMsg += (errMsgStatistics ?? "");

    _statisticsDailyDataMap =
        _transformStatisticsDataToMap(_statisticsDailyDataList);

    _detailList = [];
    String errMsgDetail = _readDetailTable(
      _decoder.tables[_detailTableName],
      _detailList,
      daysCount: latestDetailDataDayCount,
    );
    _errMsg += (errMsgDetail ?? "");

    await _checkOutStatisticsWithExpenditure();

    if ("" == _errMsg) {
      _status = "ok";
      _errMsg = null;
    } else {
      _status = "error";
    }

    return;
  }

  Future<ByteData> _loadAssetFile() async {
    final assetPath = "assets/files/empty.xlsx";
    return await rootBundle.load(assetPath);
  }

  Future<Directory> _defaultExportDirectory() async {
    Directory dir;

    if (defaultTargetPlatform == TargetPlatform.android) {
//      dir = await getExternalStorageDirectory();
      dir = Directory(defaultDataFileDir);
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

  String _readExpenditureTable(
      SpreadsheetTable table, List<ExpenditureDataItem> dataList,
      [int startRow, int countLimit]) {
    String errMsg = "";
    int count = 0;
    for (int r = startRow ?? 1; r < table.maxRows; r++) {
      final item = ExpenditureDataItem();

      bool ok = true;

      item.ID = parseInt(table.rows[r][0]);
      if (null == item.ID) {
        ok = false;
        errMsg += "${table.name}[$r][0]解析序号失败：${table.rows[r][0]}\n";
        print(errMsg);
        item.ID = dataList.length;
      }

      item.dateInt = parseExcelDate(table.rows[r][1]);
      if (null == item.dateInt) {
        ok = false;
        errMsg += "${table.name}[$r][1]解析日期失败：${table.rows[r][1]}\n";
        print(errMsg);
      }

      item.name = table.rows[r][2];
      item.comment = table.rows[r][3];

      item.price = parseDouble(table.rows[r][4]);
      if (null == item.price) {
        ok = false;
        errMsg += "${table.name}[$r][4]解析价格失败：${table.rows[r][4]}\n";
        print(errMsg);
      }

      item.count = parseInt(table.rows[r][5]);
      if (null == item.count) {
        ok = false;
        errMsg += "${table.name}[$r][5]解析数量失败：${table.rows[r][5]}\n";
        print(errMsg);
      }

      item.totalPrice = parseDouble(table.rows[r][6]);
      if (null == item.totalPrice) {
        ok = false;
        errMsg += "${table.name}[$r][6]解析总价失败：${table.rows[r][6]}\n";
        print(errMsg);
      }

      item.transportationExpense = parseDouble(table.rows[r][7]);
      item.discount = parseDouble(table.rows[r][8]);

      item.finalMoney = parseDouble(table.rows[r][9]);
      if (null == item.finalMoney) {
        ok = false;
        errMsg += "${table.name}[$r][9]解析总金额失败：${table.rows[r][9]}\n";
        print(errMsg);
      }

      if (ok) {
        dataList.add(item);

        count++;
        if (null != countLimit) {
          if (countLimit <= count) {
            break;
          }
        }
      }
    }

    return ("" == errMsg) ? null : errMsg;
  }

  Map<int, double> _transformExpenditureDataToDailyMap(
      List<ExpenditureDataItem> dataList) {
    Map<int, double> dailyDataMap = {};

    for (final item in dataList) {
      dailyDataMap.update(item.dateInt.data, (double oldValue) {
        return oldValue + item.finalMoney;
      }, ifAbsent: () {
        return item.finalMoney;
      });
    }
    return dailyDataMap;
  }

  String _readStatisticsTable(
      SpreadsheetTable table, List<DailyDataItem> dataList) {
    String errMsg = "";
    int lastDate = 0;
    bool needResort = false;
    for (int r = 1; r < table.maxRows; r++) {
      bool ok = true;
      final item = DailyDataItem();

      item.rowIndex = r;
      item.dateInt = parseExcelDate(table.rows[r][1]);
      if (null == item.dateInt) {
        ok = false;
        errMsg += "${table.name}[$r][1]解析时间失败：${table.rows[r][1]}";
//        print(errMsg);
      } else {
        item.dailyIncomeMoney = parseDouble(table.rows[r][2]) ?? 0;
        item.sumIncomeMoney = parseDouble(table.rows[r][3]) ?? 0;
        item.dailyExpenditureMoney = parseDouble(table.rows[r][4]); // 花费不补0
        item.sumExpenditureMoney = parseDouble(table.rows[r][5]) ?? 0;
        item.leftMoney = parseDouble(table.rows[r][6]) ?? 0;

        dataList.add(item);
      }

      if (!needResort) {
        if (lastDate < item.dateInt.data) {
          lastDate = item.dateInt.data;
        } else {
          needResort = true;
//        assert(false); // 未处理
          // TODO do some thing
        }
      }
    }
    if (needResort) {
//      _dailyDataList.sort(DailyDataItem.sortAsc);
      // TODO flush to file
    }

    int i = 0;
    for (final item in dataList) {
      item.pos = i++;
    }

    return errMsg;
  }

  Map<int, List<DailyDataItem>> _transformStatisticsDataToMap(
      List<DailyDataItem> dataList) {
    Map<int, List<DailyDataItem>> dataMap = {};

    for (final item in dataList) {
      dataMap.update(
        item.dateInt.data,
        (list) {
          list.add(item);
          return list;
        },
        ifAbsent: () {
          return [item];
        },
      );
    }
    return dataMap;
  }

  DateFormat _fmt = DateFormat("yyyy/MM/dd HH:mm:ss");
  String _readDetailTable(SpreadsheetTable table, List<DetailItem> dataList,
      {DateInt startDateInt, int daysCount, int lastRowIndex}) {
    List<DetailItem> tmpDataList = [];
    String errMsg = "";
    int dc = 0;
    int date = 0;
    for (int r = (lastRowIndex ?? table.maxRows) - 1; 0 < r; r--) {
      bool ok = true;
      final item = DetailItem();
      item.rowIndex = r;
      item.submittor = table.rows[r][0];

      final dt = parseExcelDateTime(table.rows[r][1]);
      assert(null != dt);
      item.commitTimeText = _fmt.format(dt);
      item.commitDateInt = parseExcelDate(table.rows[r][1]);
      if (null == item.commitDateInt) {
        ok = false;
        errMsg += "${table.name}[$r][0]解析解析日期失败：${table.rows[r][1]}";
      }
      if ((null != startDateInt) &&
          (item.commitDateInt.data < startDateInt.data)) {
        break;
      }

      item.name = table.rows[r][2];
      final newName = trimBlankToSingleSpace(item.name);
      if (item.name != newName) {
        item.name = newName;
      }

      item.money = parseDouble(table.rows[r][3]);

      if (ok) {
        tmpDataList.add(item);
      }

      if (null != daysCount) {
        if (date != item.commitDateInt.data) {
          date = item.commitDateInt.data;
          dc++;
          if (daysCount <= dc) {
            break;
          }
        }
      }
    }

    dataList.addAll(tmpDataList.reversed);

    return ("" == errMsg) ? null : errMsg;
  }

  Future<String> AddDetailData(List<List<String>> lines) async {
    int i = 0;
    while (!ready) {
      await Future.delayed(Duration(seconds: 1));
      i++;
      if (5 <= i) {
        return "初始化未成功完成！";
      }
    }

    List<DetailItem> detailDataList = [];
    String errMsgDetail = _parseDetailData(lines, detailDataList);
    if ((null != errMsgDetail) && ("" != errMsgDetail)) {
      return errMsgDetail;
    }

    _flushDetailDataToDetailTable(detailDataList);

    List<DailyDataItem> dailyDataList =
        _transformDetailDataToDailyData(detailDataList);

    _flushStatisticsDataToStatisticsTable(dailyDataList);
    _flushNameListToTable(dailyDataList);

    await _file.writeAsBytes(_decoder.encode(), flush: true);

    return null;
  }

  _flushDetailDataToDetailTable(List<DetailItem> detailDataList) {
    final table = _decoder.tables[_detailTableName];
    for (final item in detailDataList) {
      item.rowIndex = table.maxRows;
      _decoder.insertRow(_detailTableName, item.rowIndex);

      if (null != item.submittor) {
        _decoder.updateCell(_detailTableName, 0, item.rowIndex, item.submittor);
      }
      _decoder.updateCell(
          _detailTableName, 1, item.rowIndex, item.commitTimeText);
      if (null != item.name) {
        _decoder.updateCell(_detailTableName, 2, item.rowIndex, item.name);
      }
      if (null != item.money) {
        _decoder.updateCell(
            _detailTableName, 3, item.rowIndex, valueToString(item.money));
      }
    }
    _detailList.addAll(detailDataList);
    return;
  }

  String _parseDetailData(
      List<List<String>> lines, List<DetailItem> detailDataList) {
    String errMsg = "";

    for (int index = 0; index < lines.length; index++) {
      bool ok = true;
      final line = lines[index];
      final detailItem = DetailItem();
      detailItem.submittor = line[0];
      detailItem.commitTimeText = line[1];
      detailItem.commitDateInt = parseExcelDate(detailItem.commitTimeText);
      if (null == detailItem.commitDateInt) {
        ok = false;
        errMsg += "第${index + 1}行解析日期失败：${line[1]}";
      }
      detailItem.name = line[2];
      final newName = trimBlankToSingleSpace(detailItem.name);
      if (detailItem.name != newName) {
        detailItem.name = newName;
      }

      detailItem.money = parseDouble(line[3]);

      if (ok) {
        detailDataList.add(detailItem);
      }
    }

//    dailyDataList.addAll(datas.values.toList());

    return ("" == errMsg) ? null : errMsg;
  }

  List<DailyDataItem> _transformDetailDataToDailyData(
      List<DetailItem> detailDataList) {
    Map<int, DailyDataItem> datas = {};
    for (final detailItem in detailDataList) {
      datas.update(
        detailItem.commitDateInt.data,
        (oldValue) {
          if (null != detailItem.name) {
            oldValue.nameText += " " + detailItem.name;
          }
          if (null != detailItem.money) {
            oldValue.dailyIncomeMoney =
                (oldValue.dailyIncomeMoney ?? 0) + detailItem.money;
          }
          return oldValue;
        },
        ifAbsent: () {
          final daily = DailyDataItem();

          daily.dateInt = detailItem.commitDateInt;
          assert(null != daily.dateInt);

          daily.nameText = detailItem.name ?? "";
          daily.dailyIncomeMoney = detailItem.money;
          daily.sumExpenditureMoney = 0;

          return daily;
        },
      );
    }

    return datas.values.toList()..sort(DailyDataItem.sortByDateAsc);
  }

  _flushStatisticsDataToStatisticsTable(List<DailyDataItem> dailyDataList) {
    // 接到_statisticsDailyDataList的尾部

    if (dailyDataList.isEmpty) {
      return;
    }

    DailyDataItem last;

    int index = 0;
    if (_statisticsDailyDataList.isNotEmpty) {
      // 如果当前第一条与历史最后一条日期相同，需要合并
      last = _statisticsDailyDataList.last;
      final newFirst = dailyDataList.first;
      if (newFirst.dateInt.data == last.dateInt.data) {
        if (null != newFirst.dailyIncomeMoney) {
          last.dailyIncomeMoney =
              last.dailyIncomeMoney + newFirst.dailyIncomeMoney;
          last.sumIncomeMoney = last.sumIncomeMoney + newFirst.dailyIncomeMoney;
          last.leftMoney = last.leftMoney + newFirst.dailyIncomeMoney;

          _flushStatisticsItemToDecoder(last); // 更新文件
        }
        index++;
      }
    } else {
      last = DailyDataItem();
      last.sumIncomeMoney = 0;
      last.sumExpenditureMoney = 0;
      last.leftMoney = 0;
    }

    for (; index < dailyDataList.length; index++) {
      DailyDataItem item = dailyDataList[index];
      item.sumIncomeMoney = last.sumIncomeMoney + (item.dailyIncomeMoney ?? 0);
      item.sumExpenditureMoney = last.sumExpenditureMoney;
      item.leftMoney = last.leftMoney + (item.dailyIncomeMoney ?? 0);

      item.pos = _statisticsDailyDataList.length;
      _statisticsDailyDataList.add(item);

      _flushStatisticsItemToDecoder(item); // 更新文件

      _statisticsDailyDataMap.update(
        item.dateInt.data,
        (oldList) {
          oldList.add(item);
          return oldList;
        },
        ifAbsent: () {
          return [item];
        },
      );

      last = item;
    }

    return;
  }

  _flushStatisticsItemToDecoder(DailyDataItem v) {
    final table = _decoder.tables[_statisticsTableName];
    if (null == v.rowIndex) {
      v.rowIndex = table.maxRows;
      _decoder.insertRow(_statisticsTableName, v.rowIndex);
    } else {
      assert(v.rowIndex < table.maxRows);
    }

    assert(null != v.rowIndex);
    _decoder.updateCell(_statisticsTableName, 0, v.rowIndex, v.rowIndex);
    assert(null != v.dateInt);
    _decoder.updateCell(
        _statisticsTableName, 1, v.rowIndex, _formatDateInt(v.dateInt));

    if (null != v.dailyIncomeMoney) {
      _decoder.updateCell(_statisticsTableName, 2, v.rowIndex,
          valueToString(v.dailyIncomeMoney));
    }
    if (null != v.sumIncomeMoney) {
      _decoder.updateCell(
          _statisticsTableName, 3, v.rowIndex, valueToString(v.sumIncomeMoney));
    }
    if (null != v.dailyExpenditureMoney) {
      _decoder.updateCell(_statisticsTableName, 4, v.rowIndex,
          valueToString(v.dailyExpenditureMoney));
    }
    if (null != v.sumExpenditureMoney) {
      _decoder.updateCell(_statisticsTableName, 5, v.rowIndex,
          valueToString(v.sumExpenditureMoney));
    }
    if (null != v.leftMoney) {
      _decoder.updateCell(
          _statisticsTableName, 6, v.rowIndex, valueToString(v.leftMoney));
    }

    return;
  }

  _flushNameListToTable(List<DailyDataItem> dailyDataList) {
    final table = _decoder.tables[_nameListTableName];
    for (final item in dailyDataList) {
      // TODO 如果最后日期相同，要合并

      final rowIndex = table.maxRows;
      _decoder.insertRow(_nameListTableName, rowIndex);
      _decoder.updateCell(
          _nameListTableName, 0, rowIndex, _formatDateInt(item.dateInt));
      _decoder.updateCell(_nameListTableName, 1, rowIndex, item.nameText);
    }
  }

  String get summary {
    DateInt dateInt = DateInt(DateTime.now()).prevousDay;
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

  Future<String> AddExpenditureData(ExpenditureDataItem expenditure) async {
    int i = 0;
    while (!ready) {
      await Future.delayed(Duration(seconds: 1));
      i++;
      if (5 <= i) {
        return "初始化未成功完成！";
      }
    }

    _flushExpenditureDataToExpenditureTable(expenditure);

    _flushExpenditureMoneyToStatisticsTable2(
        expenditure.dateInt, expenditure.finalMoney);

    await _file.writeAsBytes(_decoder.encode(), flush: true);

    return null;
  }

  _flushExpenditureDataToExpenditureTable(ExpenditureDataItem expenditure) {
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

  _flushExpenditureMoneyToStatisticsTable2(DateInt dateInt, double money) {
    String type;
    int pos;

    _statisticsDailyDataMap.update(
      dateInt.data,
      (list) {
        type = "exist";

        final DailyDataItem item = list.last;

        item.dailyExpenditureMoney = (item.dailyExpenditureMoney ?? 0) + money;
        item.sumExpenditureMoney = (item.sumExpenditureMoney ?? 0) + money;
        item.leftMoney -= money;

        _flushStatisticsItemToDecoder(item);

        pos = item.pos;

        return list;
      },
      ifAbsent: () {
        type = "addNew";

        final newItem = DailyDataItem();

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
          final newItem = DailyDataItem();
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

  _checkOutStatisticsWithExpenditure() async {
    /// 检查统计数据与支出清单是否相吻合
    /// 如果有日支出不相等的地方，
    /// 就用支出清单的金额，替代统计数据中对应的金额

    bool modified = false;
    int minPos;
    String type;
    int testLimit = 0;
    for (final entry in _dailyExpenditureDataMap.entries) {
      int date = entry.key;
      double money = entry.value;
      testLimit++;
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
            DailyDataItem curItem = list.last;

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
          final newItem = DailyDataItem();
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
            DailyDataItem last = _statisticsDailyDataList[minPos];
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
      DailyDataItem last;
      if (0 == minPos) {
        last = DailyDataItem();
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

  Future<String> ImportDetailData(
      SpreadsheetDecoder decoder, String tableName) async {
    int i = 0;
    while (!ready) {
      await Future.delayed(Duration(seconds: 1));
      i++;
      if (5 <= i) {
        return "初始化未成功完成！";
      }
    }

    List<DetailItem> detailDataList = [];
    String errMsgDetail =
        _readDetailTable(decoder.tables[tableName], detailDataList);
    if ((null != errMsgDetail) && ("" != errMsgDetail)) {
      return errMsgDetail;
    }

    _flushDetailDataToDetailTable(detailDataList);

    List<DailyDataItem> dailyDataList =
        _transformDetailDataToDailyData(detailDataList);

    _flushStatisticsDataToStatisticsTable(dailyDataList);
    _flushNameListToTable(dailyDataList);

    await _file.writeAsBytes(_decoder.encode(), flush: true);

    for (final fn in _fnList) {
      fn(this, ready, _errMsg);
    }

    return null;
  }

  Future<String> ImportExpenditureData(
      SpreadsheetDecoder decoder, String tableName) async {
    int i = 0;
    while (!ready) {
      await Future.delayed(Duration(seconds: 1));
      i++;
      if (5 <= i) {
        return "初始化未成功完成！";
      }
    }

    List<ExpenditureDataItem> expenditureDataList = [];
    String errMsg =
        _readExpenditureTable(decoder.tables[tableName], expenditureDataList);
    if ((null != errMsg) && ("" != errMsg)) {
      return errMsg;
    }

    for (final item in expenditureDataList) {
      _flushExpenditureDataToExpenditureTable(item);
    }

    Map<int, double> dailyDataMap =
        _transformExpenditureDataToDailyMap(expenditureDataList);

    dailyDataMap.forEach((int date, double money) {
      _flushExpenditureMoneyToStatisticsTable2(DateInt.fromInt(date), money);
    });

    await _file.writeAsBytes(_decoder.encode(), flush: true);

    return null;
  }

  Future<String> prepareDetailData(DateInt startDateInt) async {
    int lastRowIndex;
    if (_detailList.isNotEmpty) {
      final first = _detailList.first;
      if (first.commitDateInt.data <= startDateInt.data) {
//        int startPos = _getDetailListStartPos(startDateInt);
//        assert(null != startPos);
        return null;
      }
      lastRowIndex = first.rowIndex;
    }

    List<DetailItem> dataList = [];
    String errMsgDetail = _readDetailTable(
        _decoder.tables[_detailTableName], dataList,
        startDateInt: startDateInt, lastRowIndex: lastRowIndex);
    if ((null != errMsgDetail) && ("" != errMsgDetail)) {
      return errMsgDetail;
    }

    if (dataList.isNotEmpty) {
      dataList.addAll(_detailList);
      _detailList = dataList;
    }

    return null;
  }

  DateInt getFirstDetailDate() {
    final table = _decoder.tables[_detailTableName];
    if (1 <= table.maxRows) {
      return parseExcelDate(table.rows[1][1]);
    }

    return null;
  }

  List<DateInt> getDetailDatePeriod() {
    if (_detailList.isEmpty) {
      return null;
    }

    DateInt firstDateInt1 = getFirstDetailDate();
    DateInt lastDateInt1 = detailList.last.commitDateInt;

    DateInt firstDateInt2;
    DateInt lastDateInt2;
    if (firstDateInt1.data < lastDateInt1.data) {
      firstDateInt2 = firstDateInt1;
      lastDateInt2 = lastDateInt1;
    } else {
      firstDateInt2 = lastDateInt1;
      lastDateInt2 = firstDateInt1;
    }

    return [firstDateInt2, lastDateInt2];
  }
}

class DailyDataItem {
  int pos;
  int rowIndex;
  DateInt dateInt;
  double dailyIncomeMoney;
  double sumIncomeMoney;
  double dailyExpenditureMoney;
  double sumExpenditureMoney;
  double leftMoney;
  String nameText;

  static int sortByDateAsc(DailyDataItem a, DailyDataItem b) {
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
  String submittor;
  String commitTimeText;
  DateInt commitDateInt;
  String name;
  double money;
}

import 'dart:ui';
import 'package:flutter/material.dart';
import 'plugins/color_loader_2.dart';
import 'plugins/color_loader_3.dart';
import 'dart:io';
import 'dart:ui';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as m;
import 'package:flutter/services.dart';

String ValidateNumFn(String value) {
  if (value.isEmpty) {
    return null;
  }

  if ("0" == value) {
    return null;
  }

  final numEP = RegExp(r'^[1-9][0-9]*$');
  if (numEP.hasMatch(value)) {
    return null;
  }
  return '请输入正确的数字';
}

String numString(int num, [bool doubleLine]) {
  assert(null != num);

  bool negative = false;
  if (num < 0) {
    negative = true;
    num = -num;
  }

  if (0 == num) {
    return "0";
  }

  String text = negative ? "-" : "";
  int wan = (num / 10000).toInt();
  int left = num % 10000;

  if (0 != wan) {
    text = "$wan万";
  }

  if (0 != left) {
    if (("" != text) && (true == doubleLine)) {
      text += "\n";
    }
    text += "$left";
  }

  return text;
}

bool isToday(DateTime dt) {
  return isSameDay(dt, DateTime.now());
}

bool isSameDay(DateTime dt1, DateTime dt2) {
  if ((null != dt1) &&
      (null != dt2) &&
      (dt1.day == dt2.day) &&
      (dt1.month == dt2.month) &&
      (dt1.year == dt2.year)) {
    return true;
  }
  return false;
}

class DateInt {
  int _data;
  DateInt(DateTime date) {
    assert(null != date);
    _data = _dt2Int(date);
//    _test();
  }
  DateInt.fromInt(int dt) {
    _data = dt;
  }

  int _dt2Int(DateTime date) {
    if (null != date) {
      return (date.year * 10000 + date.month * 100 + date.day);
    }
    return null;
  }

  DateTime get dt {
    if (null != _data) {
      return DateTime(year, month, day);
    }
    return null;
  }

  int get data => _data;

  int get year {
    assert(null != _data);
    return (_data ~/ 10000);
  }

  int get month {
    (_data ~/ 10000);
    return (_data % 10000 ~/ 100);
  }

  int get day {
    (_data ~/ 10000);
    return (_data % 100);
  }

  bool isSameDay(DateInt other) {
    assert(null != _data);
    assert(null != other);
    assert(null != other._data);

    return (_data == other._data);

//    if ((null != _data) &&
//        (null != other) &&
//        (null != other._data) &&
//        (_data == other._data)) {
//      return true;
//    }
//    return false;
  }

  DateInt get prevousDay {
    assert(null != _data);

    if (1 != day) {
      return DateInt.fromInt(_data - 1);
    }

    // 1==day
    //  1  2  3  4  5  6  7  8  9 10 11 12
    // 31 2? 31 30 31 30 31 31 30 31 30 31
    switch (month) {
      case 1 + 1: // 2
      case 3 + 1: // 4
      case 5 + 1: // 6
      case 7 + 1: // 8
      case 8 + 1: // 9
      case 10 + 1: // 11
        {
          // 同一年内，上一个月是31天
          return DateInt.fromInt(_data - 100 + 30);
        }
      case 4 + 1: // 5
      case 6 + 1: // 7
      case 9 + 1: // 10
      case 11 + 1: // 12
        {
          // 同一年内，上一个月是30天
          return DateInt.fromInt(_data - 100 + 29);
        }
      case 3:
        {
          // 2月特殊处理
          return DateInt(DateTime(year, 3, 0));
        }
      case 1:
        {
          // 1月1日
          return DateInt.fromInt(_data - 10000 + 11 * 100 + 30);
        }
      default:
        {
          assert(false);
        }
    }
  }

  DateInt get nextDay {
    assert(null != _data);

    //  1  2  3  4  5  6  7  8  9 10 11 12
    // 31 2? 31 30 31 30 31 31 30 31 30 31

    final m = month;
    final d = day;

    if (d < 28) {
      return DateInt.fromInt(_data + 1);
    }

    if (2 == month) {
      return DateInt(DateTime(year, month, d + 1));
    }

    if (d < 30) {
      return DateInt.fromInt(_data + 1);
    }

//    return DateInt(DateTime(year, month, _d + 1));

    assert(30 <= d);

    {
      // 年、月 都不变得情况
      if ((30 == d) &&
          ((1 == m) ||
              (3 == m) ||
              (5 == m) ||
              (7 == m) ||
              (8 == m) ||
              (10 == m) ||
              (12 == m))) {
        return DateInt.fromInt(_data + 1);
      }

      if (12 != month) {
        // 跨月
        return DateInt.fromInt(_data + 100 - d + 1);
      } else {
        // 12.31 跨年
        return DateInt.fromInt(_data + 10000 - 11 * 100 - 30);
      }
    }
  }

  static _testPrevousDay() {
    Map<int, int> _pairs = {
      20190101: 20181231,
      20190201: 20190131,
      20190301: 20190228,
      20190401: 20190331,
      20190501: 20190430,
      20190601: 20190531,
      20190701: 20190630,
      20190801: 20190731,
      20190901: 20190831,
      20191001: 20190930,
      20191101: 20191031,
      20191201: 20191130,
    };

    _pairs.forEach((int day, int prevousDay) {
      if (DateInt.fromInt(day).prevousDay.data != prevousDay) {
        print("_testPrevousDay $day!=$prevousDay");
        assert(false);
      }
    });
  }

  static void _testNextDay() {
    Map<int, int> _pairs = {
      // 最后一天
      20190131: 20190201,
      20190228: 20190301,
      20190331: 20190401,
      20190430: 20190501,
      20190531: 20190601,
      20190630: 20190701,
      20190731: 20190801,
      20190831: 20190901,
      20190930: 20191001,
      20191031: 20191101,
      20191130: 20191201,
      20191231: 20200101,

      // 所有月的29
      20190129: 20190130,
      20190329: 20190330,
      20190429: 20190430,
      20190529: 20190530,
      20190629: 20190630,
      20190729: 20190730,
      20190829: 20190830,
      20190929: 20190930,
      20191029: 20191030,
      20191129: 20191130,
      20191229: 20191230,

      // 大月的30
      20190130: 20190131,
      20190330: 20190331,
      20190530: 20190531,
      20190730: 20190731,
      20190830: 20190831,
      20191030: 20191031,
      20191230: 20191231,
    };

    _pairs.forEach((int day, int nextDay) {
      if (DateInt.fromInt(day).nextDay.data != nextDay) {
        print("_testNextDay $day!=$nextDay");
        assert(false);
      }
    });
  }

  static bool _tested;
  static _test() {
    if (true == _tested) {
      return;
    }
    _tested = true;

    _testPrevousDay();
    _testNextDay();
  }
}

final double _width = MediaQueryData.fromWindow(window).size.width;
final double _height = MediaQueryData.fromWindow(window).size.height;
Widget buildLoadingView({double topPadding, double height, double width}) {
  return Container(
//      color: Colors.orange,
      alignment: Alignment.topCenter,
      width: width,
      height: height ?? (_height / 2),
      child: Padding(
          padding: EdgeInsets.only(top: topPadding ?? (_height / 5)),
//        children: [
//          SizedBox(height: paddingHeight ?? (height / 5)),
          child: Stack(
            alignment: AlignmentDirectional.center,
            overflow: Overflow.visible,
            children: [
//              CircularProgressIndicator(),
              ColorLoader2(),
              ColorLoader3(radius: _width / 8, dotRadius: _width / 20),
            ],
          )
//        ],
          ));
}

Widget buildLoadingCard() {
  return Card(
      child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      buildLoadingView(),
      Card(
        color: Colors.lightBlueAccent,
        child: FittedBox(
            child: Text("正在处理\n请稍等……",
                style: TextStyle(fontSize: 50, color: Colors.deepOrange))),
      )
    ],
  ));
}

showLoading(BuildContext context) {
  // 需要停止显示的时候，要调用Navigator.of(context).pop();
  showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return buildLoadingCard();
      });
}

final RegExp _reDate = RegExp(
    r"(?<year>[0-9]{4})[^0-9](?<month>[0-9]{1,2})[^0-9](?<day>[0-9]{1,2})");
final _dtBase = DateTime(1900, 1, -1);
DateInt parseExcelDate(dynamic value) {
  if (null == value) {
    return null;
  }

  if (value is String) {
    final match = _reDate.firstMatch(value);
    if (null == match) {
      return null;
    }

    int year = int.parse(match.namedGroup("year"));
    int month = int.parse(match.namedGroup("month"));
    int day = int.parse(match.namedGroup("day"));

    return DateInt.fromInt(year * 10000 + month * 100 + day);
  } else if (value is double) {
    try {
      DateTime dt = _dtBase.add(Duration(days: value.toInt()));
      return DateInt(dt);
    } catch (err) {
      return null;
    }
  }
}

final RegExp _reDateTime = RegExp(
    r"(?<year>[0-9]{4})[^0-9](?<month>[0-9]{1,2})[^0-9](?<day>[0-9]{1,2})[^0-9](?<hour>[0-9]{1,2})[^0-9](?<minute>[0-9]{1,2})[^0-9](?<second>[0-9]{1,2})");
final _dtBase2 = DateTime(1900, 1, -1, 0, 0, 1);
DateTime parseExcelDateTime(dynamic value) {
  if (value is String) {
    final match = _reDateTime.firstMatch(value);
    if (null == match) {
      return null;
    }

    int year = int.parse(match.namedGroup("year"));
    int month = int.parse(match.namedGroup("month"));
    int day = int.parse(match.namedGroup("day"));
    int hour = int.parse(match.namedGroup("hour"));
    int minute = int.parse(match.namedGroup("minute"));
    int second = int.parse(match.namedGroup("second"));

    return DateTime(year, month, day, hour, minute, second);
  } else if (value is double) {
    try {
//      int days = value.toInt();
//      double tmp = (value - days) * 24;
//      int hours = tmp.toInt();
//      tmp = (tmp - hours) * 60;
//      int minutes = tmp.toInt();
//      tmp = (tmp - minutes) * 60;
//      int seconds = tmp.toInt();
//      DateTime dt = _dtBase.add(Duration(days: days - 1));
      DateTime dt =
          _dtBase2.add(Duration(seconds: (value * 24 * 60 * 60).toInt()));
      return dt;
    } catch (err) {
      return null;
    }
  }
}

int parseInt(dynamic v) {
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

double parseDouble(dynamic v) {
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
        }
      case int:
        {
          return (v as int).toDouble();
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

Future<void> saveAsPicture(GlobalKey key, String fullPath) async {
  final file = File(fullPath);
  final data = await getImageData(key);
  final exist = await file.exists();
  if (!exist) {
    await file.create(recursive: true);
  }
  await file.writeAsBytes(data, flush: true);
  return;
}

Future<List<int>> getImageData(GlobalKey key) async {
  RenderRepaintBoundary boundary = key.currentContext.findRenderObject();
  ui.Image uiImage = await boundary.toImage();

  //    uiImage.height;
  //    uiImage.width;

  final ByteData byteData =
      await uiImage.toByteData(format: ui.ImageByteFormat.png);
  return byteData.buffer.asUint8List();
}

showMsg(BuildContext context, String msg) {
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

String valueToString(dynamic v) {
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
        return formatDateInt(v);
      }
    default:
      {
        assert(false);
        break;
      }
  }
}

String formatDateInt(DateInt v) {
  return "${v.year}/${v.month}/${v.day}";
}

String get defaultDataFileDir => "/storage/emulated/0/供灯报表数据";
String get defaultExportFileDir => "/storage/emulated/0/供灯报表数据/导出文件";

final _reBlank = RegExp(r'[\r\n\t]');
final _reMultiSpace = RegExp(r' {2,}');
String trimBlankToSingleSpace(String text) {
  final text2 = text.replaceAll(_reBlank, " ");
  final text3 = text2.replaceAll(_reMultiSpace, " ");
  return text3.trim();
}

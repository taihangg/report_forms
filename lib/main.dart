import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:permission_handler/permission_handler.dart';
import 'plugins/common_localizations_delegate.dart';
import 'report_form_page.dart';
import 'add_detail_data_page.dart';
import 'add_expenditure_data_page.dart';
import 'add_data_page.dart';
import 'other_page.dart';

void testFn() {
  double d = -1.5;
  final d2 = d / 1.1;
  final d3 = d.ceil();

  return;
}

void main() {
//  testFn();

  MediaQueryData mediaQuery = MediaQueryData.fromWindow(window);
  double _width = mediaQuery.size.width;
  double _height = mediaQuery.size.height;
  double _topbarH = mediaQuery.padding.top;
  double _botbarH = mediaQuery.padding.bottom;
  double _pixelRatio = mediaQuery.devicePixelRatio;
  print("xxx main $_width $_height $_topbarH $_botbarH $_pixelRatio");

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        //自定义代理
        CommonLocalizationsDelegate(),
//        DefaultCupertinoLocalizations.delegate,
//        GlobalCupertinoLocalizations.delegate,
      ],
      locale: Locale("zh", "CN"),
      supportedLocales: [Locale('zh', 'CN'), Locale('en', 'US')],
      title: "供灯报表",
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: _HomePage(),
    );
  }
}

class _HomePage extends StatefulWidget {
  _HomePage({Key key}) : super(key: key);

  @override
  createState() {
    return _HomePageState();
  }
}

class _HomePageState extends State<_HomePage> {
  _HomePageState() {
    _checkPermission();
  }
  final double _width = MediaQueryData.fromWindow(window).size.width;
  final double _height = MediaQueryData.fromWindow(window).size.height;

  int _bottomBarSelectIndex = 0; // 默认第一个

  final List<Widget> _tabList = [];
  final List<Widget> _tabBarViewChildren = [];

  @override
  void initState() {
    super.initState();

    _addReportPage();
    _addDataPage();
    _addImportPage();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabList.length,
      child: Scaffold(
        resizeToAvoidBottomPadding: false, //避免软键盘把widget顶上去
        appBar: AppBar(
          //leading: Text('Tabbed AppBar'),
          //title: const Text('Tabbed AppBar'),
          title: TabBar(isScrollable: false, tabs: _tabList),
//      bottom: myTabBar,
        ),
//      body: _tabBarViewChildren[_bottomBarSelectIndex],
        body: TabBarView(children: _tabBarViewChildren),
//      bottomNavigationBar: bottomNavigateBar,
      ),
    );
  }

  _addReportPage() {
    _tabList.add(Tab(
      text: "报表",
//      icon: Icon(Icons.share),
    ));

    _tabBarViewChildren.add(ReportFormPage());
  }

  _addDataPage() {
    _tabList.add(Tab(
      text: "添加数据",
//      icon: Icon(Icons.assignment),
    ));

//    _tabBarViewChildren.add(AddDetailDataPage());
    _tabBarViewChildren.add(AddDataPage());
  }

  _addImportPage() {
    _tabList.add(Tab(
      text: "其他",
//      icon: Icon(Icons.assignment),
    ));

    _tabBarViewChildren.add(OtherPage());
  }

  _checkPermission() async {
    PermissionStatus permission = await PermissionHandler()
        .checkPermissionStatus(PermissionGroup.storage);

    if (PermissionStatus.granted != permission) {
//    bool isOpened = await PermissionHandler().openAppSettings();

      Map<PermissionGroup, PermissionStatus> status = await PermissionHandler()
          .requestPermissions([PermissionGroup.storage]);

//      if (PermissionStatus.granted != status.values.first.value) {
//        Scaffold.of(context).showSnackBar(SnackBar(
//          content: Text(
//            "请允许app读写存储的权限\n否则无法工作",
//            style: TextStyle(color: Colors.red, fontSize: 50),
//          ),
//          duration: Duration(seconds: 5),
//          backgroundColor: Colors.tealAccent,
////    action: SnackBarAction(
////      label: "button",
////      onPressed: () {
////        print("in press");
////      },
////    ),
//        ));
//      }
    }

    return;
  }
}

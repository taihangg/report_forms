import 'dart:math';
import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'common_util.dart';
import 'excel_mgr.dart';

class AddExpenditureDataPage extends StatefulWidget {
  final Widget title;
  AddExpenditureDataPage(this.title) {}
  @override
  State<StatefulWidget> createState() {
    return _AddExpenditureDataPageState();
  }
}

class _AddExpenditureDataPageState extends State<AddExpenditureDataPage> {
  _AddExpenditureDataPageState() {
    final fontSize = _width / 15;
    _textStyle = TextStyle(fontSize: fontSize);
    _boxWidth = _width * 40 / 100;
    _boxHight = fontSize * 3;
  }

  double _width = MediaQueryData.fromWindow(window).size.width;
  double _height = MediaQueryData.fromWindow(window).size.height;
  TextStyle _textStyle;
  double _boxWidth;
  double _boxHight;

  ExcelMgr _excelMgr =
      ExcelMgr(onFinishedFn: (ExcelMgr mgr, bool ok, String msg) {});

  DateTime _pickDate;
  DateFormat _fmt = DateFormat("yyyy/M/d");
  final _dateController = TextEditingController();
  final _nameController = TextEditingController();
  final _commentController = TextEditingController();
  final _priceController = TextEditingController();
  final _countController = TextEditingController();
  final _totalPriceController = TextEditingController();
  final _transportationExpenseController = TextEditingController();
  final _discountController = TextEditingController();
  final _finalMoneyController = TextEditingController();

  double _price;
  int _count;
  double _totalPrice;
  double _transportationExpense;
  double _discount;
  double _finalMoney;

  @override
  void dispose() {
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: FittedBox(child: widget.title),
          backgroundColor: Colors.grey[350],
        ),
        body: Builder(builder: (BuildContext context2) {
          return Scrollbar(
              child: SingleChildScrollView(child: _buildBody(context2)));
        }));
  }

  Widget _buildBody(BuildContext context) {
    return Column(
      children: [
        Divider(),
        _buildDateRow(),
        Divider(),
        _buildNormalRow("物品：", _nameController, TextInputType.text,
            validator: _checkName),
        Divider(),
        _buildNormalRow("说明：", _commentController, TextInputType.text),
        Divider(),
        _buildNormalRow("单价：", _priceController, TextInputType.number,
            validator: _checkPrice, tailStr: "元"),
        Divider(),
        _buildNormalRow("数量：", _countController, TextInputType.number,
            validator: _checkCount, tailStr: "个"),
        Divider(),
        _buildNormalRow("总价：", _totalPriceController, TextInputType.number,
            tailStr: "元", enable: false),
        Divider(),
        _buildNormalRow(
            "运费：", _transportationExpenseController, TextInputType.number,
            validator: _checkTransportationExpense, tailStr: "元"),
        Divider(),
        _buildNormalRow("折扣：", _discountController, TextInputType.number,
            validator: _checkDiscount, tailStr: "元"),
        Divider(),
        _buildNormalRow("总金额：", _finalMoneyController, TextInputType.number,
            tailStr: "元", enable: false),
        Divider(),
        _buildButtonRow(context),
        Divider(),
      ],
    );
  }

  Widget _buildDateRow([String tailMsg]) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Container(
          width: _width * 30 / 100,
          height: _boxHight,
          alignment: Alignment.centerRight,
          child: Text("日期：", style: _textStyle),
        ),
        GestureDetector(
          child: Container(
            width: _width * 50 / 100,
            height: _boxHight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              border:
                  Border(bottom: BorderSide(width: 1.3, color: Colors.black38)),

//        borderRadius: BorderRadius.all(Radius.circular(8.0)),
            ),
            child: TextFormField(
              controller: _dateController,
              enabled: false,
              maxLines: 1,
              minLines: 1,
              decoration: InputDecoration(
                  hintText: "日期不能为空!",
                  hintStyle:
                      TextStyle(fontSize: _width / 20, color: Colors.red[400]),
                  filled: true,
                  fillColor: Colors.grey[200]),
              style: _textStyle,
              autovalidate: true,
              validator: (String value) {
                if ("" == value) {
                  return "日期不能为空";
                }
              },
              onTap: () {
                print("onTap");
              },
//                  readOnly: true,
              onChanged: (String value) {
                print("onChanged");
              },
            ),
          ),
          onTap: () async {
            _pickDate = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
            );
            if (null != _pickDate) {
              _dateController.text = _fmt.format(_pickDate);
            } else {
              _dateController.text = "";
            }
          },
        ),
        Container(
          color: (null == tailMsg) ? null : Colors.grey[200],
          width: _width * 10 / 100,
          height: _boxHight,
          alignment: Alignment.center,
          child: Text(tailMsg ?? " ", style: _textStyle),
        ),
      ],
    );
  }

  Widget _buildNormalRow(
    String title,
    TextEditingController controller,
    TextInputType keyboardType, {
    String Function(String) validator,
    String tailStr,
    bool enable = true,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Container(
          width: _width * 30 / 100,
          height: _boxHight,
          alignment: Alignment.centerRight,
          child: FittedBox(child: Text(title, style: _textStyle)),
        ),
        Container(
          color: Colors.grey[200],
          width: _width * 50 / 100,
          height: _boxHight,
          alignment: Alignment.center,
          child: TextFormField(
            enabled: enable,
            controller: controller,
            keyboardType: keyboardType,
            maxLines: 1,
            minLines: 1,
            decoration:
                InputDecoration(filled: true, fillColor: Colors.grey[200]),
            style: _textStyle,
            autovalidate: (null != validator) ? true : false,
            validator: validator,
          ),
        ),
        Container(
          width: _width * 10 / 100,
          height: _boxHight,
          alignment: Alignment.center,
          child: Text(tailStr ?? " ", style: _textStyle),
        ),
      ],
    );
  }

  String _checkName(String value) {
    if ("" == value) {
      return "名字不能为空";
    }
  }

  String _checkPrice(String value) {
    _price = null;
    final errMsg = "请输入合理的数字";
    String msg;
    try {
      _price = double.parse(value);
      if (_price < 0) {
        _price = null;
        msg = errMsg;
      }
    } catch (err) {
      msg = errMsg;
    }

    Future(_calcTotalPriceAndFinalMoney);

    return msg;
  }

  String _checkCount(String value) {
    _count = null;
    final errMsg = "请输入合理的数字";
    String msg;
    try {
      _count = int.parse(value);
      if (_count < 0) {
        _count = null;
        msg = errMsg;
      }
    } catch (err) {
      msg = errMsg;
    }

    Future(_calcTotalPriceAndFinalMoney);

    return msg;
  }

  String _checkTransportationExpense(String value) {
    _transportationExpense = null;
    String msg;
    if ("" != value) {
      final errMsg = "请输入正确的金额";
      try {
        _transportationExpense = double.parse(value);
        if (_transportationExpense < 0) {
          _transportationExpense = null;
          msg = errMsg;
        }
      } catch (err) {
        msg = errMsg;
      }
    }

    Future(_calcFinalMoney);

    return msg;
  }

  String _checkDiscount(String value) {
    _discount = null;
    String msg;
    if ("" != value) {
      final errMsg = "请输入正确的金额";
      try {
        _discount = double.parse(value);
        if (_discount < 0) {
          _discount = null;
          msg = errMsg;
        }
      } catch (err) {
        msg = errMsg;
      }
    }

    Future(_calcFinalMoney);

    return msg;
  }

  _calcTotalPriceAndFinalMoney() {
    if ((null != _price) && (null != _count)) {
      _totalPrice = _price * _count;

      _finalMoney =
          _totalPrice + (_transportationExpense ?? 0) - (_discount ?? 0);
      _totalPriceController.text = _totalPrice.toStringAsFixed(2);
      _finalMoneyController.text = _finalMoney.toStringAsFixed(2);
    } else {
      _totalPriceController.text = "";
      _finalMoneyController.text = "";
    }
  }

  _calcFinalMoney() {
    if ((null != _price) && (null != _count)) {
      _finalMoney =
          _totalPrice + (_transportationExpense ?? 0) - (_discount ?? 0);
      _finalMoneyController.text = _finalMoney.toStringAsFixed(2);
    }
  }

  Widget _buildButtonRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        RaisedButton.icon(
//          icon: Icon(Icons.camera_alt),
          icon: Icon(Icons.clear),
          label: Text("清除", style: TextStyle(fontSize: _width / 20)),
          onPressed: () {
            _clear();
          },
        ),
        RaisedButton.icon(
          icon: Icon(Icons.done),
          label: Text("提交", style: TextStyle(fontSize: _width / 20)),
          onPressed: () async {
            final expenditure = ExpenditureDataItem();
            if (null == _pickDate) {
              return;
            }
            expenditure.dateInt = DateInt(_pickDate);

            if ("" == _nameController.text) {
              return;
            }
            expenditure.name = _nameController.text;

            expenditure.comment = _commentController.text;

            if (null == _price) {
              return;
            }
            expenditure.price = _price;

            if (null == _count) {
              return;
            }
            expenditure.count = _count;

            assert(null != _totalPrice);
            expenditure.totalPrice = _totalPrice;

            expenditure.transportationExpense = _transportationExpense;
            expenditure.discount = _discount;

            assert(null != _finalMoney);
            expenditure.finalMoney = _finalMoney;

            showLoading(context); // 显示等待画面

            await Future.delayed(Duration(milliseconds: 200)); // 等待loading画面显示

            bool ok = await _excelMgr.AddExpenditureDataTable(expenditure);
            Navigator.of(context).pop(); // 取消等待画面

            String msg;
            if (ok) {
              msg = "添加成功！";
              _clear();
            } else {
              msg = "添加失败！";
            }
            showMsg(context, msg);
          },
        ),
      ],
    );
  }

  _clear() {
    _dateController.text = "";
    _nameController.text = "";
    _commentController.text = "";
    _priceController.text = "";
    _countController.text = "";
    _totalPriceController.text = "";
    _transportationExpenseController.text = "";
    _discountController.text = "";
    _finalMoneyController.text = "";

    _pickDate = null;
    _price = null;
    _count = null;
    _totalPrice = null;
    _transportationExpense = null;
    _discount = null;
    _finalMoney = null;
    FocusScope.of(context).requestFocus(FocusNode()); // 失焦
  }
}

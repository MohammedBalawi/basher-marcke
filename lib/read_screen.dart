import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:bashar_market/shared_pref/shared.dart';
import 'package:flutter/material.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:excel/excel.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:convert';

class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  _BarcodeScannerPageState createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  List<String> scannedData = [];
  Excel? loadedExcel;
  String? originalFileName;
  Map<String, Map<String, dynamic>> scannedProducts = {};
  TextEditingController manualBarcodeController = TextEditingController();
  TextEditingController manualCheckController = TextEditingController();
  List<Map<String, dynamic>> newProducts = [];
  bool showNewProducts = false;
  dynamic q = 0;
  var d = 0.0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadNewProducts();
  }

  Future<void> _loadData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? storedData = prefs.getString('scannedProducts');
    if (storedData != null && storedData.isNotEmpty) {
      Map<String, dynamic> decodedData = json.decode(storedData);
      setState(() {
        scannedProducts = decodedData.map(
            (key, value) => MapEntry(key, Map<String, dynamic>.from(value)));
      });
    }
  }

  Future<void> _saveData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('scannedProducts', json.encode(scannedProducts));
  }

  Future<void> scanBarcode({bool isChecking = false}) async {
    try {
      var result = await BarcodeScanner.scan();
      if (result.rawContent.isNotEmpty) {
        if (isChecking) {
          _checkProductDialog(result.rawContent);
        } else {
          _showProductDialog(result.rawContent);
        }
      }
    } catch (e) {
      _showDialog('Error', 'Failed to scan barcode: $e');
    }
  }

  void _manualInput() {
    String barcode = manualBarcodeController.text.trim();
    if (barcode.isNotEmpty) {
      _showProductDialog(barcode);
    } else {
      _showDialog('Error', 'الرجاء إدخال رمز الباركود');
    }
  }

  void _manualCheck() {
    String barcode = manualCheckController.text.trim();
    if (barcode.isNotEmpty) {
      _checkProductDialog(barcode);
    } else {
      _showDialog('Error', 'الرجاء إدخال رمز الباركود للتحقق');
    }
  }

  void _showProductDialog(String barcode) {
    TextEditingController nameController = TextEditingController();
    TextEditingController priceController = TextEditingController();
    TextEditingController quantityController = TextEditingController();

    if (scannedProducts.containsKey(barcode)) {
      var product = scannedProducts[barcode]!;
      nameController.text = product['name'];
      priceController.text = product['price'].toString();
      quantityController.text = product['quantity'].toString();
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          title: Text(
            scannedProducts.containsKey(barcode)
                ? 'تعديل المنتج'
                : 'إضافة منتج',
            style: const TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTextField(
                      nameController, 'اسم المنتج', true, Icons.shopping_cart),
                  const SizedBox(height: 12),
                  _buildTextField(
                      priceController, 'السعر', true, Icons.attach_money,
                      isNumeric: true),
                  const SizedBox(height: 12),
                  _buildTextField(quantityController, 'الكمية', true,
                      Icons.production_quantity_limits,
                      isNumeric: true),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('إلغاء',
                  style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              ),
              onPressed: () {
                setState(() {
                  scannedProducts[barcode] = {
                    'name': nameController.text,
                    'price': double.tryParse(priceController.text) ?? 0.0,
                    'quantity': int.tryParse(quantityController.text) ?? 1,
                    'date': DateTime.now().toString(),
                  };
                });
                _saveData();
                Navigator.of(context).pop();
              },
              child: const Text('حفظ',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      bool? enabled, IconData icon,
      {bool isNumeric = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.blueAccent),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.blue, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _addProductToNewList(
      String barcode, String name, double price, int quantityAdded) {
    setState(() {
      int quantityToAdd = quantityAdded ?? 1;

      q += quantityToAdd;
      d += price;

      if (scannedProducts.containsKey(barcode)) {
        var existingProduct = scannedProducts[barcode]!;
        int oldQuantity = existingProduct['quantity'];

        if (oldQuantity > 0) {
          scannedProducts[barcode]!['quantity'] = oldQuantity - quantityToAdd;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("لا يمكن خصم الكمية، المخزون فارغ!")),
          );
          return;
        }
      }

      newProducts.add({
        'price': price,
        'barcode': barcode,
        'name': name,
        'quantity': quantityToAdd,
        'date': DateTime.now().toString(),
      });
    });

    _saveNewProducts();
    _saveScannedProducts();
  }

  // void _addProductToNewList(String barcode, String name, double price, int quantityAdded) {
  //   setState(() {
  //     if (scannedProducts.containsKey(barcode)) {
  //       var existingProduct = scannedProducts[barcode]!;
  //       int availableQuantity = existingProduct['quantity'];
  //
  //
  //       if (availableQuantity >= quantityAdded) {
  //         scannedProducts[barcode]!['quantity'] -= quantityAdded;
  //         scannedProducts[barcode]!['price'] = price;
  //       } else {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(content: Text("الكمية المتاحة غير كافية!")),
  //         );
  //         return;
  //       }
  //     }
  //
  //
  //     newProducts.add({
  //       'barcode': barcode,
  //       'name': name,
  //       'price': price,
  //       'quantityAdded': quantityAdded,
  //       'date': DateTime.now().toString(),
  //     });
  //   });
  //
  //   _saveNewProducts();
  //   _saveScannedProducts();
  // }

  Future<void> _saveScannedProducts() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('scannedProducts', jsonEncode(scannedProducts));
  }

  Future<void> _loadNewProducts() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedProducts = prefs.getString('newProducts');
    if (savedProducts != null) {
      setState(() {
        newProducts =
            List<Map<String, dynamic>>.from(jsonDecode(savedProducts));
      });
    }
  }

  Future<void> _saveNewProducts() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('newProducts', jsonEncode(newProducts));
  }

  void _deleteProduct(int index) {
    setState(() {
      var deletedProduct = newProducts[index];
      String barcode = deletedProduct['barcode'];
      int deletedQuantity = deletedProduct['quantity'];
      double deletedPrice = deletedProduct['price'];

      if (scannedProducts.containsKey(barcode)) {
        scannedProducts[barcode]!['quantity'] += deletedQuantity;
      }

      q -= deletedQuantity;
      d -= (deletedPrice * deletedQuantity);

      newProducts.removeAt(index);
    });

    _saveNewProducts();
    _saveScannedProducts();
  }

  void _checkProductDialog(String barcode) {
    var isExistingProduct = scannedProducts.containsKey(barcode);
    var product = isExistingProduct ? scannedProducts[barcode]! : null;

    _showAddProductDialog(
      barcode: barcode,
      existingProduct: product,
    );
  }

  void _showAddProductDialog({
    required String barcode,
    Map<String, dynamic>? existingProduct,
  }) {
    TextEditingController nameController = TextEditingController();
    TextEditingController priceController = TextEditingController();
    TextEditingController quantityController = TextEditingController();
    TextEditingController quantityAddedController = TextEditingController();
    int availableQuantity = 0;

    if (existingProduct != null) {
      var product = scannedProducts[barcode]!;
      // nameController.text = existingProduct['name'];
      // priceController.text = existingProduct['price'].toString();
      quantityController.text = existingProduct['quantity'].toString();
      nameController.text = product['name'];
      priceController.text = product['price'].toString();
      availableQuantity = product['quantity'];
      quantityAddedController.text = '1';
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          title: Row(
            children: [
              const Icon(Icons.add_circle, color: Colors.blue, size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  existingProduct == null
                      ? 'إضافة منتج جديد'
                      : 'إضافة منتج مسجل',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(
                  nameController, 'اسم المنتج', true, Icons.shopping_cart),
              const SizedBox(height: 12),
              _buildTextField(
                  priceController, 'السعر', true, Icons.attach_money,
                  isNumeric: true),
              const SizedBox(height: 12),
              _buildTextField(quantityController, 'الكمية', false,
                  Icons.production_quantity_limits,
                  isNumeric: true),
              const SizedBox(height: 12),
              _buildTextField(quantityAddedController, 'العدد المضاف', true,
                  Icons.exposure_plus_1,
                  isNumeric: true),
              const SizedBox(height: 12),
              Text(
                "المتوفر: $availableQuantity",
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'إلغاء',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              ),
              onPressed: () {
                //   _addProductToNewList(
                //     barcode,
                //     nameController.text,
                //     double.tryParse(priceController.text) ?? 0.0,
                //     int.tryParse(quantityController.text) ?? 1,
                //   );
                //   Navigator.of(context).pop();
                // },
                int quantityAdded =
                    int.tryParse(quantityAddedController.text) ?? 1;
                double newPrice = double.tryParse(priceController.text) ?? 0.0;
                _addProductToNewList(
                    barcode, nameController.text, newPrice, quantityAdded);
                Navigator.of(context).pop();
              },
              child: const Text('إضافة',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget buildNewProductsList() {
    return ListView.builder(
      itemCount: newProducts.length,
      itemBuilder: (context, index) {
        var product = newProducts[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            leading: const Icon(Icons.new_releases, color: Colors.blue),
            title: Text(product['name']),
            subtitle: Text(
                'السعر: ${product['price']} | الكمية: ${product['quantity']}'),
            trailing: Text(
              product['date'].split(' ')[0],
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        );
      },
    );
  }

  bool isDialogShowing = false;

  void _showM(BuildContext context) async {
    bool result = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Do You Logout Now?'),
          actions: [
            MaterialButton(
              onPressed: () {
                // Navigator.pop(context, true);
              },
              child: const Text(
                'Yes',
                style: TextStyle(color: Colors.blue),
              ),
            ),
            MaterialButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text(
                'No',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
    if (result ?? false) {
      _clear(context);
    }
  }

  Future<void> _clear(BuildContext context) async {
    bool clear = await SharedPrefController().clear();
    if (clear) {
      Get.delete();
      Navigator.pushReplacementNamed(context, '/login_screen');
    }
  }

  Future<void> saveToExcel() async {
    if (loadedExcel == null) {
      _showDialog('خطا', 'لا يوجد ملف محمل .');
      return;
    }

    try {
      var newExcel = Excel.createExcel();
      Sheet sheetObject = newExcel['Sheet1'];

      for (String data in scannedData) {
        List<String> rowData = data
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        sheetObject.appendRow(rowData);
      }

      var directory = await getApplicationDocumentsDirectory();
      String outputPath =
          '${directory.path}/${originalFileName ?? "Data"}_Data.xlsx';

      var file = File(outputPath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(newExcel.save()!);

      _showDialog('نجح', 'Data saved to $outputPath');

      OpenFilex.open(outputPath);
    } catch (e) {
      _showDialog('خطا', 'Failed to save Excel file: $e');
    }
  }

  Future<void> removeRowsIfFirstColumnMatches() async {
    if (loadedExcel == null) {
      _showDialog('خطأ', 'لا يوجد ملف محمل.');
      return;
    }

    try {
      var newExcel = Excel.createExcel();
      Sheet newSheet = newExcel['Sheet1'];

      // معالجة الصفوف في الملف
      for (var table in loadedExcel!.tables.keys) {
        for (var row in loadedExcel!.tables[table]!.rows) {
          if (row.isNotEmpty) {
            // الحصول على القيمة الأولى في العمود الأول من الصف
            String? firstColumnValue = row.first?.value?.toString().trim();

            // التحقق إذا كانت القيمة الأولى مطابقة لأي عنصر أول في القائمة
            bool isMatching = scannedData.any((data) {
              String firstElement =
                  data.split(',').first.trim(); // العنصر الأول من القائمة
              return firstColumnValue == firstElement;
            });

            // إذا لم يكن هناك تطابق، أضف الصف إلى الملف الجديد
            if (!isMatching) {
              List<String> rowData =
                  row.map((e) => e?.value.toString().trim() ?? '').toList();
              newSheet.appendRow(rowData);
            }
          }
        }
      }

      // حفظ الملف الجديد
      var directory = await getApplicationDocumentsDirectory();
      String outputPath =
          '${directory.path}/${originalFileName ?? "Filtered"}_Filtered.xlsx';

      var file = File(outputPath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(newExcel.save()!);

      _showDialog(
          'نجاح', 'تم تصفية البيانات وحفظ الملف الجديد إلى $outputPath');
      OpenFilex.open(outputPath);
    } catch (e) {
      _showDialog('خطأ', 'حدث خطأ أثناء تصفية البيانات: $e');
    }
  }

  void _showDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showDialogg(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  q = 0;
                  d = 0.0;
                });
                Navigator.of(context).pop(); // إغلاق الديالوج
              },
              child: Text("إعادة تعيين", style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // إغلاق الديالوج فقط
              },
              child: Text("إغلاق"),
            ),
          ],
        );
      },
    );
  }

  void calculateTotalPrice() {
    double total = 0.0;
    for (var product in newProducts) {
      total += product['price'];
    }

    _showDialog('إجمالي الأسعار', 'مجموع أسعار المنتجات المباعة: $total');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('بشار ماركت'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  // color: Colors.red,
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Center(
                  child: InkWell(
                      onTap: () {
                        _showM(context);
                      },
                      child: const Icon(Icons.arrow_forward_ios_outlined)),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/IMG-20230719-WA0011.jpg',
                fit: BoxFit.cover),
          ),
          Column(
            children: [
              const SizedBox(height: 50),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton(
                      onPressed: scanBarcode,
                      child:
                          const Text('+', style: TextStyle(color: Colors.blue)),
                    ),
                    ElevatedButton(
                      onPressed: () => scanBarcode(isChecking: true),
                      child: const Icon(
                        Icons.qr_code_2,
                        color: Colors.orange,
                      ),
                    ),
                    const Text(''),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: manualBarcodeController,
                        decoration: const InputDecoration(
                          labelText: 'أدخل رمز المنتج',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _manualInput,
                      child:
                          const Text('+', style: TextStyle(color: Colors.blue)),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Text(''),
                    Expanded(
                      child: TextField(
                        controller: manualCheckController,
                        decoration: const InputDecoration(
                          labelText: 'أدخل رمز المنتج المباع',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _manualCheck,
                      child: const Text('اضافة',
                          style: TextStyle(color: Colors.orange)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: calculateTotalPrice,
                            child: const Text(
                              'T',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              setState(() {
                                showNewProducts = !showNewProducts;
                              });
                            },
                            child: Text(
                              showNewProducts
                                  ? 'عرض المنتجات الجديدة'
                                  : 'عرض المنتجات المسجلة',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            _showDialogg('Total',
                                'مجموع الكمية المباعة : $q\nمجموع المبلغ المباعة : $d');
                          },
                          icon: Icon(Icons.recommend, color: Colors.blue),
                        ),
                      ],
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: showNewProducts
                            ? newProducts.length
                            : scannedProducts.length,
                        itemBuilder: (context, index) {
                          if (showNewProducts) {
                            var product = newProducts[index];

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  vertical: 5, horizontal: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              child: ListTile(
                                leading: const Icon(Icons.new_releases,
                                    color: Colors.blue),
                                title: Text(product['name']),
                                subtitle: InkWell(
                                  onTap: () {
                                    _showDialog('Total',
                                        ' الكمية المباعة : ${product['quantity']}\n المبلغ المباعة : ${product['price']}');
                                  },
                                  child: Text(
                                      'السعر: ${product['price']} | الكمية: ${product['quantity']} | التاريخ: ${product['date']}'),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () => _deleteProduct(
                                      index), // حذف المنتج عند الضغط
                                ),
                              ),
                            );
                          } else {
                            String key = scannedProducts.keys.elementAt(index);
                            var product = scannedProducts[key]!;

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  vertical: 5, horizontal: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              child: ListTile(
                                leading: const Icon(Icons.shopping_cart,
                                    color: Colors.green),
                                title: Text(product['name']),
                                subtitle: Text(
                                    'السعر: ${product['price']} | الكمية: ${product['quantity']} | التاريخ: ${product['date']}'),
                                onTap: () => _showProductDialog(key),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

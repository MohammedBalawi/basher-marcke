import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'dart:typed_data';
import 'package:bashar_market/shared_pref/shared.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:excel/excel.dart';
import 'package:get/get.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:open_filex/open_filex.dart';

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
  Map<String, double> totalByDate = {};
  int _selectedIndex = 0;
  Map<String, List<Map<String, dynamic>>> productsByDate = {};
  dynamic q = 0;
  var d = 0.0;
  double t = 0.0;
  TextEditingController searchController = TextEditingController();
  List<Map<String, dynamic>> filteredProducts = [];


  @override
  void initState() {
    super.initState();
    _loadData();
    _loadNewProducts();
    _loadTotalPrice();
    filteredProducts = List.from(newProducts);
    setState(() {
      newProducts = newProducts.where((product) => product != null).toList();
    });
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
  Future<void> _loadTotalPrice() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      t = prefs.getDouble('totalPrice') ?? 0.0; // تحميل القيمة أو تعيين 0.0 إذا لم تكن موجودة
    });
  }
  Future<void> _saveTotalPrice() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('totalPrice', t); // حفظ القيمة الجديدة
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
  Future<void> saveProductsToExcel() async {
    var excel = Excel.createExcel(); // إنشاء ملف Excel جديد
    Sheet sheetObject = excel['Products']; // إنشاء صفحة داخل الملف

    // إضافة عناوين الأعمدة
    sheetObject.appendRow(["اسم المنتج", "السعر", "الكمية", "التاريخ"]);

    // إضافة المنتجات إلى الملف
    for (var product in newProducts) {
      sheetObject.appendRow([
        product['name'],
        product['price'].toString(),
        product['quantity'].toString(),
        product['date'].split('.')[0], // إزالة الميلي ثانية لجعل التاريخ واضحًا
      ]);
    }

    try {
      // حفظ الملف في التخزين المحلي
      var directory = await getApplicationDocumentsDirectory();
      String outputPath = "${directory.path}/Products_List.xlsx";

      var file = File(outputPath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(excel.save()!);

      // إشعار المستخدم بنجاح العملية
      _showDialog("تم الحفظ بنجاح", "تم حفظ المنتجات في ملف Excel: \n$outputPath");

      // فتح الملف تلقائيًا بعد الحفظ
      OpenFilex.open(outputPath);
    } catch (e) {
      _showDialog("خطأ", "فشل في حفظ ملف Excel: $e");
    }
  }
  Future<void> saveToExcel() async {
    if (newProducts.isEmpty) {
      _showDialog("خطأ", "لا يوجد بيانات لحفظها.");
      return;
    }

    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Sheet1'];

      // ✅ **إضافة العناوين بالترتيب الصحيح**
      sheetObject.appendRow(["اسم المنتج", "السعر", "الكمية", "التاريخ", "الوقت"]);

      // ✅ **إضافة البيانات مع الترتيب الجديد**
      for (var product in newProducts) {
        sheetObject.appendRow([
          product['name'],   // ✅ اسم المنتج أولًا
          product['price'],  // ✅ السعر
          product['quantity'], // ✅ الكمية
          product['date'].split('.')[0],   // ✅ التاريخ
          product['time'].split('.')[0],   // ✅ الوقت
        ]);
      }

      var directory = await getApplicationDocumentsDirectory();
      String outputPath =
          '${directory.path}/المبيعات_${DateTime.now().toString().split('.')[0].replaceAll(':', '-')}.xlsx';

      var file = File(outputPath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(excel.save()!);

      _showDialog("نجاح", "تم حفظ البيانات في الملف:\n$outputPath");

      // ✅ **فتح الملف تلقائيًا بعد الحفظ**
      OpenFilex.open(outputPath);
    } catch (e) {
      _showDialog("خطأ", "حدث خطأ أثناء حفظ الملف: $e");
    }
  }
  void _deleteProduct(int index) {
    setState(() {
      var deletedProduct = newProducts[index];
      String name = deletedProduct['name'];
      int deletedQuantity = deletedProduct['quantity'];
      double deletedPrice = deletedProduct['price'];
      String date = deletedProduct['date'];

      // **إضافة الكمية المحذوفة إلى `scannedProducts` (المخزون)**
      if (scannedProducts.containsKey(name)) {
        scannedProducts[name]!['quantity'] += deletedQuantity;
      } else {
        // **إذا لم يكن المنتج موجودًا في `scannedProducts`، يتم إضافته كمخزون جديد**
        scannedProducts[name] = {
          'name': name,
          'quantity': deletedQuantity,
          'price': deletedPrice,
          'date': date,
        };
      }

      // **حذف المنتج من `newProducts`**
      newProducts.removeAt(index);

      // **تحديث المجموع اليومي (`totalByDate`)**
      if (totalByDate.containsKey(date)) {
        totalByDate[date] = (totalByDate[date]! - (deletedPrice * deletedQuantity)).clamp(0.0, double.infinity);

        // **إذا أصبح المجموع 0، يتم حذف التاريخ من القائمة**
        if (totalByDate[date] == 0) {
          totalByDate.remove(date);
        }
      }

      // **حفظ البيانات بعد الحذف**
      _saveNewProducts();
      _saveScannedProducts();
      _saveTotalPrice();
    });

    _showDialog("تم الحذف", "تم استرجاع الكمية إلى المخزون بنجاح.");
  }
  Future<void> loadProductsFromExcel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result != null) {
        Uint8List? bytes;

        if (result.files.single.bytes != null) {
          bytes = Uint8List.fromList(result.files.single.bytes!);
        } else {
          File file = File(result.files.single.path!);
          bytes = Uint8List.fromList(await file.readAsBytes());
        }

        if (bytes == null) {
          _showDialog("خطأ", "فشل في تحميل الملف.");
          return;
        }

        var excel = Excel.decodeBytes(bytes);
        String sheetName = excel.tables.keys.first;
        Sheet sheetObject = excel[sheetName];

        List<Map<String, dynamic>> importedProducts = [];

        for (var row in sheetObject.rows.skip(1)) {
          if (row.length >= 5) {
            String name = row[0]?.value?.toString() ?? "غير معروف";
            double price = double.tryParse(row[1]?.value?.toString() ?? "0") ?? 0.0;
            int quantity = int.tryParse(row[2]?.value?.toString() ?? "0") ?? 0;
            String date = row[3]?.value?.toString() ?? DateTime.now().toString().split(' ')[0];
            String time = row[4]?.value?.toString() ?? DateTime.now().toString().split(' ')[1];

            // **التحقق مما إذا كان المنتج موجودًا بنفس التفاصيل (الاسم، السعر، الكمية، التاريخ، والوقت)**
            bool isDuplicate = newProducts.any((product) =>
            product['name'] == name &&
                product['price'] == price &&
                product['quantity'] == quantity &&
                product['date'] == date &&
                product['time'] == time);

            if (!isDuplicate) {
              // **إذا لم يكن المنتج مكررًا، نضيفه إلى القائمة**
              importedProducts.add({
                'name': name,
                'price': price,
                'quantity': quantity,
                'date': date,
                'time': time,
              });

              // **خصم الكمية من `scannedProducts` (المخزون)**
              if (scannedProducts.containsKey(name)) {
                int currentStock = scannedProducts[name]!['quantity'];
                if (currentStock >= quantity) {
                  scannedProducts[name]!['quantity'] -= quantity;
                } else {
                  _showDialog("تنبيه", "الكمية في المخزون غير كافية للمنتج: $name");
                }
              } else {
                _showDialog("تنبيه", "المنتج $name غير موجود في المخزون.");
              }

              // **إضافة البيانات إلى `totalByDate` حسب التاريخ**
              if (totalByDate.containsKey(date)) {
                totalByDate[date] = totalByDate[date]! + (price * quantity);
              } else {
                totalByDate[date] = price * quantity;
              }
            }
          }
        }

        setState(() {
          newProducts.addAll(importedProducts);
        });

        _saveNewProducts();
        _saveScannedProducts();
        _saveTotalPrice();

        _showDialog("نجاح", "تم استيراد ${importedProducts.length} منتجًا جديدًا بنجاح!");
      } else {
        _showDialog("إلغاء", "لم يتم اختيار أي ملف.");
      }
    } catch (e) {
      _showDialog("خطأ", "حدث خطأ أثناء قراءة ملف Excel: $e");
    }
  }
  void _addProductToNewList(String barcode, String name, double price, int quantityAdded) {
    setState(() {
      String currentDate = DateTime.now().toString().split(' ')[0]; // استخراج التاريخ الحالي
      String currentTime = DateTime.now().toString().split(' ')[1].split('.')[0]; // استخراج الوقت بدون الميكروثانية

      // **التحقق مما إذا كان المنتج موجودًا بالفعل بنفس التفاصيل**
      bool isDuplicate = newProducts.any((product) =>
      product['name'] == name &&
          product['price'] == price &&
          product['quantity'] == quantityAdded &&
          product['date'] == currentDate &&
          product['time'] == currentTime);

      if (!isDuplicate) {
        // **التحقق من توفر المنتج في `scannedProducts` وخصم الكمية**
        if (scannedProducts.containsKey(name)) {
          int currentStock = scannedProducts[name]!['quantity'];

          if (currentStock >= quantityAdded) {
            // **خصم الكمية من المخزون**
            scannedProducts[name]!['quantity'] -= quantityAdded;

            // **إضافة المنتج إلى قائمة `newProducts` مع التاريخ والوقت**
            newProducts.add({
              'barcode': barcode,
              'name': name,
              'price': price,
              'quantity': quantityAdded,
              'date': currentDate, // **إضافة التاريخ**
              'time': currentTime, // **إضافة الوقت**
            });

            // **إضافة المنتج إلى `totalByDate` حسب التاريخ**
            if (totalByDate.containsKey(currentDate)) {
              totalByDate[currentDate] = totalByDate[currentDate]! + (price * quantityAdded);
            } else {
              totalByDate[currentDate] = price * quantityAdded;
            }

            _saveNewProducts();
            _saveScannedProducts();
            _saveTotalPrice();
          } else {
            _showDialog("تنبيه", "لا يوجد كمية كافية من المنتج: $name في المخزون.");
          }
        } else {
          _showDialog("تنبيه", "المنتج $name غير موجود في المخزون.");
        }
      } else {
        _showDialog("إشعار", "هذا المنتج موجود بالفعل بنفس البيانات ولن يتم إضافته.");
      }
    });
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
    );}
  Future<void> _saveScannedProducts() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('scannedProducts', jsonEncode(scannedProducts));
  }
  Future<void> _loadNewProducts() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedProducts = prefs.getString('newProducts');
    if (savedProducts != null) {
      setState(() {
          t = prefs.getDouble('totalPrice') ?? 0.0; // تحميل القيمة أو تعيين 0.0 إذا لم تكن موجودة

        newProducts =
            List<Map<String, dynamic>>.from(jsonDecode(savedProducts));
      });
    }
  }
  Future<void> _saveNewProducts() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('newProducts', jsonEncode(newProducts));
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
  })
  {
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
          String originalPrice = priceController.text;
          String originalQuantity = quantityAddedController.text;

  
        return StatefulBuilder(
            builder: (context, setStateDialog) {
              return
              AlertDialog(
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
                        nameController, 'اسم المنتج', true,
                        Icons.shopping_cart),
                    const SizedBox(height: 12),

                        _buildTextField(
                            priceController, 'السعر', true, Icons.attach_money,
                            isNumeric: true),

                    const SizedBox(height: 12),
                    _buildTextField(quantityController, 'الكمية', false,
                        Icons.production_quantity_limits,
                        isNumeric: true),
                    const SizedBox(height: 12),
                    _buildTextField(
                        quantityAddedController, 'العدد المضاف', true,
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
                      int quantityAdded =
                          int.tryParse(quantityAddedController.text) ?? 1;
                      double newPrice = double.tryParse(priceController.text) ??
                          0.0;
                      _addProductToNewList(
                          barcode, nameController.text, newPrice,
                          quantityAdded);
                      Navigator.of(context).pop();
                    },
                    child: const Text('إضافة',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              );

            });
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
    totalByDate.clear(); // تصفير البيانات لمنع التكرار

    for (var product in newProducts) {
      // ✅ **تحديد التاريخ بناءً على مصدر البيانات**
      String date = product['date'].split(' ')[0]; // استخراج التاريخ فقط

      double totalPrice = product['price'];

      if (totalByDate.containsKey(date)) {
        totalByDate[date] = totalByDate[date]! + totalPrice;
      } else {
        totalByDate[date] = totalPrice;
      }
    }

    setState(() {
      t = totalByDate.values.fold(0.0, (a, b) => a + b);
    });

    _saveTotalPrice();

    List<MapEntry<String, double>> sortedEntries = totalByDate.entries.toList();
    sortedEntries.sort((a, b) {
      DateTime dateA = DateTime.tryParse(a.key) ?? DateTime(2000, 1, 1);
      DateTime dateB = DateTime.tryParse(b.key) ?? DateTime(2000, 1, 1);
      return dateB.compareTo(dateA);
    });

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('إجمالي أسعار البيع'),
          content: SizedBox(
            height: 400,
            width: double.maxFinite,
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(
                      height: 300,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: sortedEntries.length,
                        itemBuilder: (context, index) {
                          var entry = sortedEntries[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      children: [
                                        const TextSpan(
                                          text: "التاريخ: ",
                                          style: TextStyle(
                                              fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                                        ),
                                        TextSpan(
                                          text: "${entry.key}\n",
                                          style: const TextStyle(
                                              fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                                        ),
                                        const TextSpan(
                                          text: "الإجمالي: ",
                                          style: TextStyle(
                                              fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                                        ),
                                        TextSpan(
                                          text: "${entry.value} شيكل",
                                          style: const TextStyle(
                                              fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () {
                                    setState(() {
                                      _deleteDate(entry.key, productsByDate);
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(),
                    RichText(
                      text: TextSpan(
                        children: [
                          const TextSpan(
                            text: "المجموع الكلي: ",
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                          TextSpan(
                            text: "$t شيكل",
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("إغلاق"),
            ),
          ],
        );
      },
    );
  }
  void _showSearchDialog(BuildContext context) {
    TextEditingController searchController = TextEditingController();
    List<Map<String, dynamic>> searchResults = [];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
              title: const Text(
                '🔎 البحث في المنتجات المباعة',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // **حقل البحث**
                  TextField(
                    controller: searchController,
                    onChanged: (query) {
                      setStateDialog(() {
                        searchResults = newProducts.where((product) {
                          String productName = product['name'].toString().toLowerCase();
                          return productName.contains(query.toLowerCase());
                        }).toList();
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'أدخل اسم المنتج',
                      prefixIcon: const Icon(Icons.search, color: Colors.blue),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // **عرض النتائج**
                  searchResults.isNotEmpty
                      ? SizedBox(
                    height: 300,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: searchResults.length,
                      itemBuilder: (context, index) {
                        var product = searchResults[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: ListTile(
                            leading: const Icon(Icons.shopping_bag, color: Colors.blue),
                            title: Text(product['name']),
                            subtitle: Text(
                              'السعر: ${product['price']} | الكمية: ${product['quantity']} | التاريخ: ${product['date']} | الوقت: ${product['time']}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      },
                    ),
                  )
                      : const Text(
                    'لا يوجد نتائج للبحث!',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'إغلاق',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
  void _deleteDate(String date, Map<String, List<Map<String, dynamic>>> productsByDate) {
    setState(() {
      if (productsByDate.containsKey(date)) {
        // حذف جميع المنتجات المرتبطة بهذا التاريخ
        productsByDate.remove(date);
        totalByDate.remove(date); // إزالة المجموع لهذا اليوم أيضًا
      }
    });

    _saveNewProducts();
    _saveTotalPrice();
  }
  void filterProducts(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredProducts = newProducts; // إظهار جميع المنتجات إذا كان الإدخال فارغًا
      } else {
        filteredProducts = newProducts.where((product) {
          String productName = product['name'].toString().toLowerCase();
          String productDate = product['date'].toString().split(' ')[0];

          return productName.contains(query.toLowerCase()) ||
              productDate.contains(query.toLowerCase());
        }).toList();
      }
    });
  }
  Future<void> saveScannedProductsToExcel() async {
    if (scannedProducts.isEmpty) {
      _showDialog("خطأ", "لا يوجد بيانات لحفظها.");
      return;
    }

    try {
      var excel = Excel.createExcel();
      String sheetName = excel.tables.keys.first;
      Sheet sheetObject = excel[sheetName];

      if (sheetObject.rows.isEmpty) {
        sheetObject.appendRow(["اسم المنتج", "السعر", "الكمية", "التاريخ", "الوقت"]);
      }

      scannedProducts.forEach((key, product) {
        sheetObject.appendRow([
          product['name'],
          product['price'],
          product['quantity'],
          product['date'] ?? DateTime.now().toString().split(' ')[0], // إذا لم يكن هناك تاريخ، استخدم الحالي
          product['time'] ?? DateTime.now().toString().split(' ')[1].split('.')[0],
        ]);
      });

      var directory = await getApplicationDocumentsDirectory();
      String outputPath =
          '${directory.path}/المخزون_${DateTime.now().toString().split('.')[0].replaceAll(':', '-')}.xlsx';

      var file = File(outputPath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(excel.save()!);

      _showDialog("نجاح", "تم حفظ بيانات المخزون في الملف:\n$outputPath");

      OpenFilex.open(outputPath);
    } catch (e) {
      _showDialog("خطأ", "حدث خطأ أثناء حفظ الملف: $e");
    }
  }
  Future<void> loadScannedProductsFromExcel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result != null) {
        Uint8List? bytes;

        if (result.files.single.bytes != null) {
          bytes = Uint8List.fromList(result.files.single.bytes!);
        } else {
          File file = File(result.files.single.path!);
          bytes = Uint8List.fromList(await file.readAsBytes());
        }

        if (bytes == null) {
          _showDialog("خطأ", "فشل في تحميل الملف.");
          return;
        }

        var excel = Excel.decodeBytes(bytes);
        String sheetName = excel.tables.keys.first; // استخدام الشيت الأولى
        Sheet sheetObject = excel[sheetName];

        int updatedCount = 0;
        int addedCount = 0;

        for (var row in sheetObject.rows.skip(1)) {
          if (row.length >= 3) {
            String name = row[0]?.value?.toString() ?? "غير معروف";
            double price = double.tryParse(row[1]?.value?.toString() ?? "0") ?? 0.0;
            int quantity = int.tryParse(row[2]?.value?.toString() ?? "0") ?? 0;

            // **إذا كان المنتج موجودًا، نقارن القيم ونحدثها إذا لزم الأمر**
            if (scannedProducts.containsKey(name)) {
              var existingProduct = scannedProducts[name];

              if (existingProduct!['price'] != price || existingProduct['quantity'] != quantity) {
                scannedProducts[name] = {
                  'name': name,
                  'price': price,
                  'quantity': quantity,
                };
                updatedCount++; // ✅ تحديث المنتج
              }
            } else {
              // **إذا لم يكن المنتج موجودًا، نضيفه**
              scannedProducts[name] = {
                'name': name,
                'price': price,
                'quantity': quantity,
              };
              addedCount++; // ✅ إضافة منتج جديد
            }
          }
        }

        setState(() {}); // تحديث الواجهة بعد التعديلات
        _saveScannedProducts(); // حفظ البيانات بعد التعديل

        _showDialog("نجاح", "تم تحديث $updatedCount منتجًا وإضافة $addedCount منتجًا جديدًا.");
      } else {
        _showDialog("إلغاء", "لم يتم اختيار أي ملف.");
      }
    } catch (e) {
      _showDialog("خطأ", "حدث خطأ أثناء تحميل الملف: $e");
    }
  }
  void _deleteProductByKey(String key) {
    setState(() {
      scannedProducts.remove(key); // حذف المنتج من القائمة
    });

    _saveScannedProducts(); // حفظ التغييرات في SharedPreferences

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("تم حذف المنتج بنجاح!")),
    );
  }
  void checkForUpdate() async {
    final updateInfo = await InAppUpdate.checkForUpdate();
    if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
      await InAppUpdate.performImmediateUpdate();
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(' Basher',style: TextStyle(
          color: Colors.blue,
          fontWeight: FontWeight.bold,
        ),),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => _showSearchDialog(context),
          icon: const Icon(Icons.search_outlined),
        ),


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
              const SizedBox(height: 100),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton(
                      onPressed: scanBarcode,
                      child:
                          const Text('+', style: TextStyle(color: Colors.blue,fontSize: 35)),
                    ),
                    ElevatedButton(
                      onPressed: () => scanBarcode(isChecking: true),
                      child: const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: Colors.orange,size: 50,
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
                        itemCount: showNewProducts ? newProducts.length : scannedProducts.length,
                        itemBuilder: (context, index) {
                          if (showNewProducts) {

                            // var product = newProducts[index];
                            var product = newProducts.reversed.toList()[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              child: ListTile(
                                leading: const Icon(Icons.new_releases, color: Colors.blue),
                                title: Text(product['name']),
                                subtitle: InkWell(
                                  onTap: () {
                                    _showDialog(
                                      'Total',
                                      ' الكمية المباعة : ${product['quantity']}\n المبلغ المباعة : ${product['price']}',
                                    );
                                  },
                                  child:  Text(
                                    'السعر: ${product['price']} | الكمية: ${product['quantity']} | التاريخ: ${product['date']} | الوقت: ${product['time']}',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteProduct(index), // حذف المنتج عند الضغط
                                ),
                              ),
                            );
                          } else {
                            List<String> reversedKeys = scannedProducts.keys.toList().reversed.toList();
                            String key = reversedKeys[index];
                            var product = scannedProducts[key]!;

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              child: ListTile(
                                leading: const Icon(Icons.shopping_cart, color: Colors.green),
                                title: Text(product['name']),
                                subtitle: Text(
                                    'السعر: ${product['price']} | الكمية: ${product['quantity']} | التاريخ: ${product['date']} | الوقت: ${product['time']}'),

                                    onTap: () => _showProductDialog(key),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteProductByKey(key), // حذف المنتج عند الضغط
                                ),
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
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
            _executeFunction(index);
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.add),
            label: " رفع المنتجات",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.upload_file),
            label: "تحميل المنتجات",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.save),
            label: "رفع المبيعات",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calculate),
            label: " حفظ المبيعات",
          ),
        ],
      ),



    );
  }
  void _executeFunction(int index) {
    switch (index) {
      case 0:
        loadScannedProductsFromExcel();
        break;
      case 1:
        saveScannedProductsToExcel();
        break;
      case 2:
        loadProductsFromExcel();
        break;
      case 3:
        saveToExcel();
        break;
    }
  }

}
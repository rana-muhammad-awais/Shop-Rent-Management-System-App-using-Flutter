import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import '../models/shop.dart';
import '../models/rent_payment.dart';

class ExcelService {
  Future<void> exportReport(String title, List<Shop> shops,
      List<RentRecord> rentRecords, List<Payment> payments) async {
    // 1. Storage Permission
    if (Platform.isAndroid) {
      var status = await Permission.storage.request();
      if (!status.isGranted) {
        status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) return;
      }
    }

    // 2. Create Excel
    var excel = Excel.createExcel();
    Sheet sheetObject = excel[title];
    excel.setDefaultSheet(title);

    // Styles
    CellStyle headerStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString("#366092"),
      horizontalAlign: HorizontalAlign.Center,
    );

    // Title
    sheetObject.merge(
        CellIndex.indexByString("A1"), CellIndex.indexByString("H1"));
    var titleCell = sheetObject.cell(CellIndex.indexByString("A1"));
    titleCell.value = TextCellValue(title);
    titleCell.cellStyle = CellStyle(
        bold: true, fontSize: 14, horizontalAlign: HorizontalAlign.Center);

    // Headers
    List<String> headers = [
      'Shop ID',
      'Shop Name',
      'Shopkeeper',
      'Contact',
      'Monthly Rent',
      'Prev Balance',
      'Total Due',
      'Remaining'
    ];

    for (var i = 0; i < headers.length; i++) {
      var cell = sheetObject
          .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 2));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    // Data
    int rowIndex = 3;
    Map<int, RentRecord> rentMap = {for (var r in rentRecords) r.shopId: r};

    // Calculate payments per shop
    Map<int, double> paidMap = {};
    for (var p in payments) {
      // Simple filter: assume payments passed are relevant for this month logic
      paidMap[p.shopId] = (paidMap[p.shopId] ?? 0) + p.amount;
    }

    for (var shop in shops) {
      final record = rentMap[shop.id];
      final prevBal =
          record?.previousBalance ?? shop.initialPreviousBalance; // Simplified
      final totalDue = record?.totalDue ?? (shop.monthlyRent + prevBal);
      final paid = paidMap[shop.id] ?? 0.0;
      final remaining = totalDue - paid;

      List<CellValue> rowData = [
        IntCellValue(shop.id),
        TextCellValue(shop.shopName),
        TextCellValue(shop.shopkeeperName),
        TextCellValue(shop.contactNumber),
        DoubleCellValue(shop.monthlyRent),
        DoubleCellValue(prevBal),
        DoubleCellValue(totalDue),
        DoubleCellValue(remaining),
      ];

      for (var i = 0; i < rowData.length; i++) {
        var cell = sheetObject.cell(
            CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex));
        cell.value = rowData[i];
      }
      rowIndex++;
    }

    // 3. Save
    try {
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      final String path =
          "${directory!.path}/${title.replaceAll(' ', '_')}.xlsx";
      var fileBytes = excel.save();

      File(path)
        ..createSync(recursive: true)
        ..writeAsBytesSync(fileBytes!);

      // Open file
      OpenFile.open(path);
    } catch (e) {
      print("Error saving excel: $e");
    }
  }
}

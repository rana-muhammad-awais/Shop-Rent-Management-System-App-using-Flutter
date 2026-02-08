import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../models/rent_payment.dart';
import '../models/shop.dart';

class ReceiptService {
  Future<void> generateAndShareReceipt(Payment payment, Shop shop) async {
    final pdf = pw.Document();

    // Load font and image
    final font = await PdfGoogleFonts.poppinsRegular();
    final fontBold = await PdfGoogleFonts.poppinsBold();

    Uint8List? stampBytes;
    try {
      final byteData = await rootBundle.load('assets/stamp.png');
      stampBytes = byteData.buffer.asUint8List();
    } catch (e) {
      print("Error loading stamp: $e");
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a6,
        margin: const pw.EdgeInsets.all(16),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 2),
              borderRadius: pw.BorderRadius.circular(10),
            ),
            padding: const pw.EdgeInsets.all(16),
            child: pw.Stack(
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Center(
                      child: pw.Text('RENT RECEIPT',
                          style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 20,
                              decoration: pw.TextDecoration.underline)),
                    ),
                    pw.SizedBox(height: 20),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Date:',
                            style: pw.TextStyle(font: font, fontSize: 10)),
                        pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text(payment.paymentDate,
                                  style: pw.TextStyle(
                                      font: fontBold, fontSize: 12)),
                            ])
                      ],
                    ),
                    pw.Divider(thickness: 0.5),
                    pw.SizedBox(height: 10),
                    _buildRow('Shop Name:', shop.shopName, font, fontBold),
                    _buildRow(
                        'Shopkeeper:', shop.shopkeeperName, font, fontBold),
                    _buildRow('Payment ID:', '#${payment.id}', font, fontBold),
                    pw.SizedBox(height: 10),
                    pw.Divider(thickness: 0.5),
                    pw.SizedBox(height: 10),
                    _buildRow(
                        'Amount Paid:',
                        'Rs. ${payment.amount.toStringAsFixed(2)}',
                        font,
                        fontBold,
                        textSize: 16),
                    _buildRow('Method:', payment.paymentMethod, font, fontBold),
                    pw.Spacer(),
                    pw.Center(
                      child: pw.Text('Thank you for your business!',
                          style: pw.TextStyle(
                              font: font,
                              fontSize: 10,
                              fontStyle: pw.FontStyle.italic,
                              color: PdfColors.grey700)),
                    ),
                  ],
                ),
                // Stamp
                if (stampBytes != null)
                  pw.Positioned(
                    bottom: 30,
                    right: 16,
                    child: pw.Transform.rotate(
                      angle: -0.5,
                      child: pw.Container(
                        height: 100,
                        width: 100,
                        child: pw.Opacity(
                          opacity: 0.8,
                          child: pw.Image(
                            pw.MemoryImage(stampBytes),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  // Fallback if image missing
                  pw.Positioned(
                    bottom: 30,
                    right: 16,
                    child: pw.Transform.rotate(
                      angle: -0.5,
                      child: pw.Container(
                        height: 80,
                        width: 80,
                        decoration: pw.BoxDecoration(
                          border:
                              pw.Border.all(color: PdfColors.green, width: 3),
                          shape: pw.BoxShape.circle,
                        ),
                        child: pw.Center(
                          child: pw.Text('PAID',
                              style: pw.TextStyle(
                                  font: fontBold,
                                  fontSize: 20,
                                  color: PdfColors.green)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );

    // Save to temporary file
    final output = await getTemporaryDirectory();
    final file = File("${output.path}/receipt_${payment.id}.pdf");
    await file.writeAsBytes(await pdf.save());

    // Share via WhatsApp or System Share
    // WhatsApp direct sharing of file is tricky on Android without specific intent,
    // so we use share_plus which opens the system share sheet (User selects WhatsApp).
    // Alternatively, we can send a TEXT message to WhatsApp with details.

    // Option A: Share PDF File
    await Share.shareXFiles([XFile(file.path)],
        text: 'Rent Receipt for ${shop.shopName}');
  }

  pw.Widget _buildRow(
      String label, String value, pw.Font font, pw.Font fontBold,
      {double textSize = 12}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: 10)),
          pw.Text(value,
              style: pw.TextStyle(font: fontBold, fontSize: textSize)),
        ],
      ),
    );
  }

  Future<void> sendWhatsAppMessage(String phoneNumber, String message) async {
    // Format: whatsapp://send?phone=91XXXXXXXXXX&text=Hello
    // Clean number
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (!cleanNumber.startsWith('91') && cleanNumber.length == 10) {
      cleanNumber = '91$cleanNumber'; // Assume India
    }

    final Uri url = Uri.parse(
        "whatsapp://send?phone=$cleanNumber&text=${Uri.encodeComponent(message)}");

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw 'Could not launch WhatsApp';
    }
  }

  Future<void> generateMonthlyReportPdf(
      String title, List<Shop> shops, List<Payment> payments) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.poppinsRegular();
    final fontBold = await PdfGoogleFonts.poppinsBold();

    // Calculate totals per shop
    Map<int, double> paidMap = {};
    for (var p in payments) {
      paidMap[p.shopId] = (paidMap[p.shopId] ?? 0) + p.amount;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Center(
                  child: pw.Text(title,
                      style: pw.TextStyle(font: fontBold, fontSize: 18))),
            ),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              context: context,
              border: pw.TableBorder.all(),
              headerStyle:
                  pw.TextStyle(font: fontBold, fontWeight: pw.FontWeight.bold),
              cellStyle: pw.TextStyle(font: font),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey300),
              headers: ['Shop Name', 'Shopkeeper', 'Rent', 'Paid', 'Status'],
              data: shops.map((shop) {
                final paid = paidMap[shop.id] ?? 0.0;
                final status = paid >= shop.monthlyRent
                    ? "PAID"
                    : "DUE"; // Simplified logic
                return [
                  shop.shopName,
                  shop.shopkeeperName,
                  shop.monthlyRent.toStringAsFixed(0),
                  paid.toStringAsFixed(0),
                  status
                ];
              }).toList(),
            ),
          ];
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File("${output.path}/${title.replaceAll(' ', '_')}.pdf");
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([XFile(file.path)], text: title);
  }
}

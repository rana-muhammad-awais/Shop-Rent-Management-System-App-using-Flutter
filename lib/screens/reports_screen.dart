import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';
import '../services/excel_service.dart';
import '../services/receipt_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ExcelService _excelService = ExcelService();
  bool _isGenerating = false;

  Future<void> _exportExcel(String type) async {
    setState(() => _isGenerating = true);
    final service = Provider.of<FirebaseService>(context, listen: false);

    try {
      if (type == 'current') {
        final month = DateFormat('yyyy-MM').format(DateTime.now());
        final allPaymentsRaw = await service.getPayments();
        final relevantPayments = allPaymentsRaw
            .where((p) => p.paymentDate.startsWith(month))
            .toList();

        await _excelService.exportReport(
            "Rent Report $month", service.shops, [], relevantPayments);
      } else {
        final allPayments = await service.getPayments();
        await _excelService.exportReport(
            "All Time Summary", service.shops, [], allPayments);
      }

      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Report Saved! Check Downloads.')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _exportPdf() async {
    setState(() => _isGenerating = true);
    final service = Provider.of<FirebaseService>(context, listen: false);

    try {
      final month = DateFormat('yyyy-MM').format(DateTime.now());
      final allPayments = await service.getPayments();
      final relevantPayments =
          allPayments.where((p) => p.paymentDate.startsWith(month)).toList();

      await ReceiptService().generateMonthlyReportPdf(
          "Rent Report $month", service.shops, relevantPayments);

      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF Generated! Sharing...')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: Text('Reports & Downloads',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isGenerating
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _buildReportCard(
                  title: "Current Month Excel",
                  subtitle:
                      "Detailed report for ${DateFormat('MMMM yyyy').format(DateTime.now())}",
                  icon: Icons.table_chart,
                  color: Colors.green,
                  onTap: () => _exportExcel('current'),
                ),
                const SizedBox(height: 16),
                _buildReportCard(
                  title: "All Time Summary (Excel)",
                  subtitle: "Complete payment history for all shops",
                  icon: Icons.history,
                  color: Colors.orange,
                  onTap: () => _exportExcel('all'),
                ),
                const SizedBox(height: 16),
                _buildReportCard(
                  title: "Monthly PDF Report",
                  subtitle: "Printable PDF summary for sharing",
                  icon: Icons.picture_as_pdf,
                  color: Colors.red,
                  onTap: () => _exportPdf(),
                ),
              ],
            ),
    );
  }

  Widget _buildReportCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 5))
            ]),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(subtitle,
                      style: GoogleFonts.poppins(
                          color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.download, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}

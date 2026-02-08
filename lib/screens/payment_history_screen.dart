import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/rent_payment.dart';
import '../services/firebase_service.dart';
import '../services/receipt_service.dart';
import 'package:intl/intl.dart';

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  bool _isLoading = true;
  List<Payment> _payments = [];
  List<Payment> _filteredPayments = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final service = Provider.of<FirebaseService>(context, listen: false);
    final data = await service.getPayments();
    if (mounted) {
      setState(() {
        _payments = data;
        _filteredPayments = data;
        _isLoading = false;
      });
      _filterPayments(_searchController.text);
    }
  }

  void _filterPayments(String query) {
    if (query.isEmpty) {
      setState(() => _filteredPayments = _payments);
      return;
    }

    final service = Provider.of<FirebaseService>(context, listen: false);
    final lowerQuery = query.toLowerCase();

    setState(() {
      _filteredPayments = _payments.where((payment) {
        final shop = service.shops.firstWhere((s) => s.id == payment.shopId,
            orElse: () => service.shops.first);

        return shop.shopName.toLowerCase().contains(lowerQuery) ||
            shop.shopkeeperName.toLowerCase().contains(lowerQuery) ||
            payment.id.toString().contains(lowerQuery);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: Text('Payment History',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
              onPressed: _fetchData,
              icon: const Icon(Icons.refresh, color: Colors.black))
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search Shop, Name or ID...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              onChanged: _filterPayments,
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredPayments.isEmpty
                    ? Center(
                        child: Text("No payments found",
                            style: GoogleFonts.poppins()))
                    : ListView.separated(
                        padding: const EdgeInsets.all(24),
                        itemCount: _filteredPayments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (ctx, index) {
                          final payment = _filteredPayments[index];
                          return _buildPaymentCard(payment);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(Payment payment) {
    // Need shop name, but Payment model only has ID. Ideally fetch shop map.
    // For now, simpler implementation.
    final service = Provider.of<FirebaseService>(context, listen: false);
    final shop = service.shops.firstWhere((s) => s.id == payment.shopId,
        orElse: () => service.shops.first);
    // ^ Fallback risky if shop deleted, but okay for MVP.

    String formattedDate = payment.paymentDate;
    try {
      // Try to parse if it contains time
      if (payment.paymentDate.contains(' ')) {
        final parts = payment.paymentDate.split(' ');
        if (parts.length >= 2) {
          // Basic parsing: YYYY-MM-DD HH:mm
          // We can just display it as is, or format it.
          // Let's just keep it simple: Date at Time
          formattedDate = "${parts[0]} at ${parts[1]}";
        }
      }
    } catch (e) {
      // ignore
    }

    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2))
          ]),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
          child: const Icon(Icons.check, color: Colors.green),
        ),
        title: Text(shop.shopName,
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        subtitle: Text(
            "#${payment.id} • $formattedDate • ${payment.paymentMethod}",
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("₹${payment.amount.toInt()}",
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, color: Colors.green)),
            PopupMenuButton(
              onSelected: (value) async {
                if (value == 'share') {
                  // Share Receipt
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Generating Receipt...")));
                  try {
                    await ReceiptService()
                        .generateAndShareReceipt(payment, shop);
                  } catch (e) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text("Error: $e")));
                  }
                }
                if (value == 'edit') _editPayment(payment);
                if (value == 'delete') _deletePayment(payment);
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                    value: 'share',
                    child: Row(children: [
                      Icon(Icons.share, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Text("Share Receipt")
                    ])),
                const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit, color: Colors.black, size: 20),
                      SizedBox(width: 8),
                      Text("Edit")
                    ])),
                const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text("Delete", style: TextStyle(color: Colors.red))
                    ])),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _editPayment(Payment payment) {
    // Show Dialog to edit amount/notes
    final amountCtrl = TextEditingController(text: payment.amount.toString());
    final notesCtrl = TextEditingController(text: payment.notes);

    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text("Edit Payment"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                      controller: amountCtrl,
                      decoration: const InputDecoration(labelText: "Amount"),
                      keyboardType: TextInputType.number),
                  TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(labelText: "Notes")),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Cancel")),
                ElevatedButton(
                    onPressed: () async {
                      final newAmount =
                          double.tryParse(amountCtrl.text) ?? payment.amount;
                      final updated = Payment(
                          id: payment.id,
                          shopId: payment.shopId,
                          rentRecordId: payment.rentRecordId,
                          amount: newAmount,
                          paymentDate: payment.paymentDate,
                          paymentMethod: payment.paymentMethod,
                          notes: notesCtrl.text);
                      await Provider.of<FirebaseService>(context, listen: false)
                          .updatePayment(updated);
                      if (mounted) {
                        Navigator.pop(ctx);
                        _fetchData();
                      }
                    },
                    child: const Text("Save"))
              ],
            ));
  }

  void _deletePayment(Payment payment) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text("Delete Payment"),
              content: const Text("Are you sure? This cannot be undone."),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Cancel")),
                TextButton(
                    onPressed: () async {
                      await Provider.of<FirebaseService>(context, listen: false)
                          .deletePayment(payment.id);
                      if (mounted) {
                        Navigator.pop(ctx);
                        _fetchData();
                      }
                    },
                    child: const Text("Delete",
                        style: TextStyle(color: Colors.red)))
              ],
            ));
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';
import '../models/rent_payment.dart';
import '../services/receipt_service.dart';
import '../models/shop.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  int? _selectedShopId;
  late TextEditingController _monthController;
  late TextEditingController _amountController;
  late TextEditingController _dateController;
  late TextEditingController _notesController;
  String _paymentMethod = 'Cash';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _monthController =
        TextEditingController(text: DateFormat('yyyy-MM').format(now));
    _dateController =
        TextEditingController(text: DateFormat('yyyy-MM-dd').format(now));
    _amountController = TextEditingController();
    _notesController = TextEditingController();

    // Ensure shops are loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FirebaseService>(context, listen: false).fetchShops();
    });
  }

  @override
  void dispose() {
    _monthController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _savePayment() async {
    if (_formKey.currentState!.validate() && _selectedShopId != null) {
      final service = Provider.of<FirebaseService>(context, listen: false);

      try {
        // Logic: Get or Create Rent Record -> Then Add Payment
        // 1. Check/Create Rent Record
        final monthYear = _monthController.text.trim();
        int? rentRecordId;

        var rentRecord =
            await service.getRentRecord(_selectedShopId!, monthYear);
        if (rentRecord == null) {
          // Need to create one. Get shop details for rent amount.
          final shop = service.shops.firstWhere((s) => s.id == _selectedShopId);
          // Fetch current balance to set as 'previousBalance' for this new record
          final currentBalance = service.getBalanceForShop(_selectedShopId!);

          rentRecordId = await service.createRentRecord(
              _selectedShopId!, monthYear, shop.monthlyRent, currentBalance);
        } else {
          rentRecordId = rentRecord.id;
        }

        // 2. Add Payment
        final payment = Payment(
          id: 0, // Ignored
          shopId: _selectedShopId!,
          rentRecordId: rentRecordId,
          amount: double.parse(_amountController.text),
          paymentDate:
              "${_dateController.text.trim()} ${DateFormat('HH:mm').format(DateTime.now())}",
          paymentMethod: _paymentMethod,
          notes: _notesController.text.trim(),
        );

        final savedPayment = await service.addPayment(payment);

        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Payment Recorded!')));

          Shop? shop = service.shops.firstWhere((s) => s.id == _selectedShopId);
          _showReceiptDialog(savedPayment, shop);
        }
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } else if (_selectedShopId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please select a shop')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirebaseService>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: Text('Record Payment',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel('Select Shop'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedShopId,
                    isExpanded: true,
                    hint: Text('Choose a shop',
                        style: GoogleFonts.poppins(color: Colors.grey)),
                    items: service.shops.map((shop) {
                      return DropdownMenuItem<int>(
                        value: shop.id,
                        child:
                            Text(shop.shopName, style: GoogleFonts.poppins()),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedShopId = val),
                  ),
                ),
              ),
              if (_selectedShopId != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4),
                  child: Text(
                    "Due Amount: ₹${service.getBalanceForShop(_selectedShopId!).toInt()}",
                    style: GoogleFonts.poppins(
                        color: Colors.redAccent, fontWeight: FontWeight.bold),
                  ),
                ),
              const SizedBox(height: 16),
              _buildTextField('Month (YYYY-MM)', _monthController,
                  isRequired: true),
              const SizedBox(height: 16),
              _buildTextField('Amount (₹)', _amountController,
                  isRequired: true, keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              _buildTextField('Date (YYYY-MM-DD)', _dateController,
                  isRequired: true),
              const SizedBox(height: 16),
              _buildLabel('Payment Method'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _paymentMethod,
                    isExpanded: true,
                    items: ['Cash', 'UPI', 'Bank Transfer', 'Cheque', 'Other']
                        .map((m) {
                      return DropdownMenuItem<String>(
                        value: m,
                        child: Text(m, style: GoogleFonts.poppins()),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _paymentMethod = val!),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildTextField('Notes', _notesController),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _savePayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50), // Green for money
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: service.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Confirm Payment',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.grey[700],
      ),
    );
  }

  void _showReceiptDialog(Payment payment, Shop shop) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('Payment Successful',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
            'Would you like to generate a receipt for ${shop.shopName}?',
            style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // Exit screen
            },
            child: Text('Skip', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              try {
                final receiptService = ReceiptService();
                await receiptService.generateAndShareReceipt(payment, shop);
                if (mounted) {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                }
              } catch (e) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            icon: const Icon(Icons.share, size: 18),
            label: Text('Share PDF',
                style: GoogleFonts.poppins(color: Colors.white)),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              try {
                final receiptService = ReceiptService();
                await receiptService.sendWhatsAppMessage(shop.contactNumber,
                    "Rent Receipt\n\nShop: ${shop.shopName}\nAmount: ₹${payment.amount}\nDate: ${payment.paymentDate}\n\nReceived with thanks!");
                if (mounted) {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                }
              } catch (e) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('Error sharing: $e')));
              }
            },
            icon: const Icon(Icons.message, size: 18),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366)),
            label: Text('WhatsApp',
                style: GoogleFonts.poppins(color: Colors.white)),
          )
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {bool isRequired = false, TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: isRequired
              ? (v) => v == null || v.isEmpty ? 'Required' : null
              : null,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
          style: GoogleFonts.poppins(),
        ),
      ],
    );
  }
}

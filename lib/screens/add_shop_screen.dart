import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/shop.dart';
import '../services/firebase_service.dart';

class AddShopScreen extends StatefulWidget {
  final Shop? shop; // If null, we are adding. If provided, we are editing.

  const AddShopScreen({super.key, this.shop});

  @override
  State<AddShopScreen> createState() => _AddShopScreenState();
}

class _AddShopScreenState extends State<AddShopScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _shopkeeperController;
  late TextEditingController _contactController;
  late TextEditingController _rentController;
  late TextEditingController _addressController;
  late TextEditingController _prevBalController;
  late TextEditingController _advanceController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.shop?.shopName);
    _shopkeeperController =
        TextEditingController(text: widget.shop?.shopkeeperName);
    _contactController =
        TextEditingController(text: widget.shop?.contactNumber);
    _rentController =
        TextEditingController(text: widget.shop?.monthlyRent.toString() ?? '0');
    _addressController = TextEditingController(text: widget.shop?.address);
    _prevBalController = TextEditingController(
        text: widget.shop?.initialPreviousBalance.toString() ?? '0');
    _advanceController = TextEditingController(
        text: widget.shop?.advancePayment.toString() ?? '0');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _shopkeeperController.dispose();
    _contactController.dispose();
    _rentController.dispose();
    _addressController.dispose();
    _prevBalController.dispose();
    _advanceController.dispose();
    super.dispose();
  }

  Future<void> _saveShop() async {
    if (_formKey.currentState!.validate()) {
      final service = Provider.of<FirebaseService>(context, listen: false);

      final newShop = Shop(
        id: widget.shop?.id ?? 0, // ID ignored for add
        shopName: _nameController.text.trim(),
        shopkeeperName: _shopkeeperController.text.trim(),
        contactNumber: _contactController.text.trim(),
        monthlyRent: double.tryParse(_rentController.text) ?? 0.0,
        address: _addressController.text.trim(),
        initialPreviousBalance: double.tryParse(_prevBalController.text) ?? 0.0,
        advancePayment: double.tryParse(_advanceController.text) ?? 0.0,
      );

      try {
        print("Attempting to add shop: ${newShop.shopName}"); // Debug log
        if (widget.shop == null) {
          await service.addShop(newShop);
          print("Shop added successfully");
          if (mounted) {
            await showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                      title: const Text("Success"),
                      content: const Text("Shop has been added successfully!"),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text("OK"))
                      ],
                    ));
          }
        } else {
          await service.updateShop(newShop);
          print("Shop updated successfully");
          if (mounted) {
            await showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                      title: const Text("Success"),
                      content: const Text("Shop details updated successfully!"),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text("OK"))
                      ],
                    ));
          }
        }
        if (mounted) Navigator.pop(context);
      } catch (e, stack) {
        print("Error adding shop: $e");
        print(stack);
        if (mounted) {
          showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                    title: const Text("Error"),
                    content: Text("Failed to save shop. \nError: $e"),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("Close"))
                    ],
                  ));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: Text(widget.shop == null ? 'Add New Shop' : 'Edit Shop',
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
            children: [
              _buildTextField('Shop Name *', _nameController, isRequired: true),
              const SizedBox(height: 16),
              _buildTextField('Shopkeeper Name', _shopkeeperController),
              const SizedBox(height: 16),
              _buildTextField('Contact Number', _contactController,
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 16),
              _buildTextField('Monthly Rent (₹) *', _rentController,
                  isRequired: true, keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              _buildTextField('Address', _addressController),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                      child: _buildTextField(
                          'Prev. Balance', _prevBalController,
                          keyboardType: TextInputType.number)),
                  const SizedBox(width: 16),
                  Expanded(
                      child: _buildTextField('Advance', _advanceController,
                          keyboardType: TextInputType.number)),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _saveShop,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Provider.of<FirebaseService>(context).isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Save Details',
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

  Widget _buildTextField(String label, TextEditingController controller,
      {bool isRequired = false, TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
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

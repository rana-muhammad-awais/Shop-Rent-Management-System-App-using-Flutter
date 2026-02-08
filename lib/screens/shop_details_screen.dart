import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/shop.dart';
import '../services/firebase_service.dart';
import 'add_shop_screen.dart';
import 'package:intl/intl.dart';

class ShopDetailsScreen extends StatefulWidget {
  final Shop shop;

  const ShopDetailsScreen({super.key, required this.shop});

  @override
  State<ShopDetailsScreen> createState() => _ShopDetailsScreenState();
}

class _ShopDetailsScreenState extends State<ShopDetailsScreen> {
  // We need to fetch history
  List<Map<String, dynamic>> _history = [];
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    final service = Provider.of<FirebaseService>(context, listen: false);
    // Fetch 6 months history
    final history = await service.getShopHistory(widget.shop.id);

    if (mounted) {
      setState(() {
        _history = history;
        _isLoadingHistory = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirebaseService>(context);
    // Find the shop in the list to ensure we have the latest data (in case of edit)
    final currentShop = service.shops
        .firstWhere((s) => s.id == widget.shop.id, orElse: () => widget.shop);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: Text(currentShop.shopName,
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.black),
            onPressed: () async {
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => AddShopScreen(shop: currentShop)));
              setState(() {}); // Refresh if returned
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Info Card
            _buildInfoCard(currentShop),
            const SizedBox(height: 24),

            // 2. Stats Row
            Row(
              children: [
                Expanded(
                    child: _buildStatBox("Monthly Rent",
                        "₹${currentShop.monthlyRent.toInt()}", Colors.blue)),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildStatBox(
                        "Due Amount",
                        "₹${service.getBalanceForShop(currentShop.id).toInt()}",
                        Colors.redAccent)),
              ],
            ),
            const SizedBox(height: 24),

            // 3. Actions
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final Uri url =
                          Uri.parse("tel:${currentShop.contactNumber}");
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      } else {
                        if (context.mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text("Could not launch dialer")));
                      }
                    },
                    icon: const Icon(Icons.call),
                    label: const Text("Call"),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16))),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            Text("Recent History (Last 6 Months)",
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            _isLoadingHistory
                ? const Center(child: CircularProgressIndicator())
                : _buildHistoryList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    if (_history.isEmpty) {
      return const Text("No history available.");
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _history.length,
      itemBuilder: (ctx, index) {
        final item = _history[index];
        final remaining = item['remaining'] as double;
        final rent = item['rent'] as double;
        final paid = item['paid'] as double;
        final isClear = remaining <= 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(item['month'],
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  Text(isClear ? "CLEARED" : "BAL: ₹${remaining.toInt()}",
                      style: GoogleFonts.poppins(
                          color: isClear ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Rent: ₹${rent.toInt()}",
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: Colors.grey[700])),
                  Text("Paid: ₹${paid.toInt()}",
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: Colors.green[700])),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoCard(Shop shop) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 5))
          ]),
      child: Column(
        children: [
          _buildInfoRow(Icons.person, "Shopkeeper", shop.shopkeeperName),
          const Divider(height: 32),
          _buildInfoRow(Icons.phone, "Contact", shop.contactNumber),
          const Divider(height: 32),
          _buildInfoRow(Icons.location_on, "Address",
              shop.address.isNotEmpty ? shop.address : "No Address"),
          const Divider(height: 32),
          _buildInfoRow(Icons.monetization_on, "Advance Amount",
              "₹${shop.advancePayment.toInt()}"),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: Colors.blueGrey, size: 20),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
            Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        )
      ],
    );
  }

  Widget _buildStatBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.poppins(
                  color: color, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/shop.dart';
import '../models/rent_payment.dart';

class FirebaseService extends ChangeNotifier {
  final String _baseUrl = "https://shoprentmanager-default-rtdb.firebaseio.com";
  // NOTE: In a production app, use secure storage or a backend proxy.
  // This API key is visible but Restricted access should be configured in Firebase Console.
  final String _apiKey = "AIzaSyA829dKp9LNDB099OSoGFIM1EBfCLRiTAU";

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<Shop> _shops = [];
  List<Shop> get shops => _shops;

  // Cache for rent calculations (ShopID -> Balance)
  Map<int, double> _balances = {};

  // Dashboard Stats
  double _totalDue = 0;
  double get totalDue => _totalDue;

  double _totalCollected = 0;
  double get totalCollected => _totalCollected;

  int _paidShopsCount = 0;
  int get paidShopsCount => _paidShopsCount;

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Cache for Data
  List<RentRecord> _cachedRentRecords = [];
  List<Payment> _cachedPayments = [];
  bool _dataLoaded = false;

  // --- Core Calculation Logic (The Ledger) ---

  /// Re-calculates global stats and per-shop balances using CACHED data.
  /// Formula: Balance = (All Rents Generated + Initial Balance) - (All Payments Made)
  void calculateDashboardStats() {
    try {
      if (!_dataLoaded) return; // Wait for initial load

      // 1. Summarize Rents per Shop
      Map<int, double> shopRentGenerated = {};
      for (var r in _cachedRentRecords) {
        shopRentGenerated[r.shopId] =
            (shopRentGenerated[r.shopId] ?? 0) + r.rentAmount;
      }

      // 2. Summarize Payments per Shop
      double tempCollected = 0;
      Map<int, double> shopPayments = {};
      for (var p in _cachedPayments) {
        tempCollected += p.amount;
        shopPayments[p.shopId] = (shopPayments[p.shopId] ?? 0) + p.amount;
      }

      _totalCollected = tempCollected;

      // 3. Calculate Balances per Shop
      _balances.clear();
      _totalDue = 0;
      _paidShopsCount = 0;

      for (var shop in _shops) {
        double generated = shopRentGenerated[shop.id] ?? 0.0;
        double paid = shopPayments[shop.id] ?? 0.0;
        double initial = shop.initialPreviousBalance;

        double balance = (initial + generated) - paid;
        _balances[shop.id] = balance;

        if (balance > 0) {
          _totalDue += balance;
        } else {
          _paidShopsCount++;
        }
      }

      notifyListeners();
    } catch (e) {
      print("Error calculating stats: $e");
    }
  }

  String _getUrl(String endpoint) {
    return "$_baseUrl/$endpoint.json";
  }

  // --- Counters & IDs ---
  Future<int> _getNextId(String counterName) async {
    try {
      final response =
          await http.get(Uri.parse(_getUrl("counters/$counterName")));
      int currentId = 0;
      if (response.body != 'null') {
        currentId = int.tryParse(response.body) ?? 0;
      }
      final nextId = currentId + 1;
      await http.put(
        Uri.parse(_getUrl("counters/$counterName")),
        body: nextId.toString(),
      );
      return nextId;
    } catch (e) {
      print("Error generating ID: $e");
      return DateTime.now().millisecondsSinceEpoch;
    }
  }

  // --- Core Data Fetching (The Fix) ---
  Future<void> fetchShops() async {
    if (_dataLoaded) return; // Prevent excessive reloading
    await _forceReloadData();
  }

  Future<void> _forceReloadData() async {
    try {
      setLoading(true);

      // Fetch Shops
      final shopResponse = await http.get(Uri.parse(_getUrl("shops")));
      _shops = [];
      if (shopResponse.statusCode == 200 && shopResponse.body != 'null') {
        final data = json.decode(shopResponse.body);
        void processShop(dynamic v) {
          if (v != null)
            _shops.add(Shop.fromJson(Map<String, dynamic>.from(v)));
        }

        if (data is Map)
          data.values.forEach(processShop);
        else if (data is List) data.forEach(processShop);
        _shops.sort((a, b) => a.shopName.compareTo(b.shopName));
      }

      // Fetch Rents
      final rentResponse = await http.get(Uri.parse(_getUrl("rent_records")));
      _cachedRentRecords = [];
      if (rentResponse.statusCode == 200 && rentResponse.body != 'null') {
        final data = json.decode(rentResponse.body);
        void processRent(dynamic v) {
          if (v != null)
            _cachedRentRecords
                .add(RentRecord.fromJson(Map<String, dynamic>.from(v)));
        }

        if (data is Map)
          data.values.forEach(processRent);
        else if (data is List) data.forEach(processRent);
      }

      // Fetch Payments
      final payResponse = await http.get(Uri.parse(_getUrl("payments")));
      _cachedPayments = [];
      if (payResponse.statusCode == 200 && payResponse.body != 'null') {
        final data = json.decode(payResponse.body);
        void processPayment(dynamic v) {
          if (v != null)
            _cachedPayments.add(Payment.fromJson(Map<String, dynamic>.from(v)));
        }

        if (data is Map)
          data.values.forEach(processPayment);
        else if (data is List) data.forEach(processPayment);
        _cachedPayments.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
      }

      _dataLoaded = true;

      // Auto-generate rent for current month if missing
      await _checkAndGenerateAutoRent();

      // Calculate initial stats
      calculateDashboardStats();
    } catch (e) {
      print("Error fetching data: $e");
    } finally {
      setLoading(false);
    }
  }

  Future<void> _checkAndGenerateAutoRent() async {
    final now = DateTime.now();
    final currentMonth = "${now.year}-${now.month.toString().padLeft(2, '0')}";

    // Check local cache
    Set<String> existingRecords = {};
    for (var r in _cachedRentRecords) {
      existingRecords.add("${r.shopId}-${r.monthYear}");
    }

    bool addedAny = false;
    for (var shop in _shops) {
      if (!existingRecords.contains("${shop.id}-$currentMonth")) {
        print("Auto-generating rent for Shop ${shop.id} ($currentMonth)");
        await createRentRecord(shop.id, currentMonth, shop.monthlyRent, 0);
        addedAny = true;
      }
    }

    // If we added rent, calculate stats again to reflect it immediately
    if (addedAny) calculateDashboardStats();
  }

  Future<void> addShop(Shop shop) async {
    try {
      setLoading(true);
      final id = await _getNextId("shops");
      final newShop = Shop(
        id: id,
        shopName: shop.shopName,
        shopkeeperName: shop.shopkeeperName,
        contactNumber: shop.contactNumber,
        monthlyRent: shop.monthlyRent,
        address: shop.address,
        initialPreviousBalance: shop.initialPreviousBalance,
        advancePayment: shop.advancePayment,
      );

      // Optimistic Update
      _shops.add(newShop);
      _shops.sort((a, b) => a.shopName.compareTo(b.shopName));
      notifyListeners();

      await http.put(
        Uri.parse(_getUrl("shops/$id")),
        body: json.encode(newShop.toJson()),
      );

      // Generate rent for current month
      final now = DateTime.now();
      final monthYear = "${now.year}-${now.month.toString().padLeft(2, '0')}";
      await createRentRecord(id, monthYear, newShop.monthlyRent, 0.0);

      calculateDashboardStats();
    } catch (e) {
      print("Error adding shop: $e");
      // Rollback would go here in a robust system
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  Future<void> updateShop(Shop shop) async {
    try {
      setLoading(true);

      // Optimistic Update
      final index = _shops.indexWhere((s) => s.id == shop.id);
      if (index != -1) {
        _shops[index] = shop;
        notifyListeners();
      }

      await http.put(
        Uri.parse(_getUrl("shops/${shop.id}")),
        body: json.encode(shop.toJson()),
      );

      calculateDashboardStats();
    } catch (e) {
      print("Error updating shop: $e");
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  // --- Rent Records ---
  Future<List<RentRecord>> getRentRecordsForShop(int shopId) async {
    if (!_dataLoaded) await fetchShops();
    return _cachedRentRecords.where((r) => r.shopId == shopId).toList();
  }

  Future<RentRecord?> getRentRecord(int shopId, String monthYear) async {
    // Check cache first
    try {
      return _cachedRentRecords
          .firstWhere((r) => r.shopId == shopId && r.monthYear == monthYear);
    } catch (e) {
      return null;
    }
  }

  Future<int> createRentRecord(int shopId, String monthYear, double rentAmount,
      double prevBalance) async {
    final id = await _getNextId("rent_records");
    final record = RentRecord(
      id: id,
      shopId: shopId,
      monthYear: monthYear,
      rentAmount: rentAmount,
      previousBalance: 0,
      totalDue: rentAmount,
    );

    // Update Cache
    _cachedRentRecords.add(record);

    await http.put(
      Uri.parse(_getUrl("rent_records/$id")),
      body: json.encode(record.toJson()),
    );
    return id;
  }

  // --- Payments ---
  Future<List<Payment>> getPayments({int? shopId}) async {
    if (!_dataLoaded) await fetchShops();
    if (shopId == null) return _cachedPayments;
    return _cachedPayments.where((p) => p.shopId == shopId).toList();
  }

  Future<Payment> addPayment(Payment payment) async {
    try {
      setLoading(true);
      final id = await _getNextId("payments");
      final newPayment = Payment(
        id: id,
        shopId: payment.shopId,
        rentRecordId: payment.rentRecordId,
        amount: payment.amount,
        paymentDate: payment.paymentDate,
        paymentMethod: payment.paymentMethod,
        notes: payment.notes,
      );

      // Optimistic Update
      _cachedPayments.insert(0, newPayment); // Add to top
      calculateDashboardStats(); // Recalc immediately

      await http.put(
        Uri.parse(_getUrl("payments/$id")),
        body: json.encode(newPayment.toJson()),
      );

      return newPayment;
    } finally {
      setLoading(false);
    }
  }

  Future<void> updatePayment(Payment payment) async {
    try {
      setLoading(true);

      // Optimistic Update
      final index = _cachedPayments.indexWhere((p) => p.id == payment.id);
      if (index != -1) {
        _cachedPayments[index] = payment;
        calculateDashboardStats();
      }

      await http.patch(
        Uri.parse(_getUrl("payments/${payment.id}")),
        body: json.encode(payment.toJson()),
      );
    } catch (e) {
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  Future<void> deletePayment(int paymentId) async {
    try {
      setLoading(true);

      _cachedPayments.removeWhere((p) => p.id == paymentId);
      calculateDashboardStats();

      await http.delete(Uri.parse(_getUrl("payments/$paymentId")));
    } catch (e) {
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  // --- Exposed Logic for UI ---

  double getBalanceForShop(int shopId) {
    return _balances[shopId] ?? 0.0;
  }

  /// Returns a computed history based on the ledger CACHE.
  Future<List<Map<String, dynamic>>> getShopHistory(int shopId) async {
    if (!_dataLoaded) await fetchShops();

    List<Map<String, dynamic>> history = [];

    final shop =
        _shops.firstWhere((s) => s.id == shopId, orElse: () => _shops[0]);
    double initialBalance = shop.initialPreviousBalance;

    final rents = _cachedRentRecords.where((r) => r.shopId == shopId).toList();
    final payments = _cachedPayments.where((p) => p.shopId == shopId).toList();

    Set<String> months = {};
    for (var r in rents) months.add(r.monthYear);
    for (var p in payments) {
      if (p.paymentDate.length >= 7) {
        months.add(p.paymentDate.substring(0, 7));
      }
    }

    List<String> sortedMonths = months.toList()..sort();
    double runningBalance = initialBalance;

    for (var month in sortedMonths) {
      double rentForMonth = 0;
      var monthlyRents = rents.where((r) => r.monthYear == month);
      for (var r in monthlyRents) rentForMonth += r.rentAmount;

      double paidForMonth = 0;
      var monthlyPayments =
          payments.where((p) => p.paymentDate.startsWith(month));
      for (var p in monthlyPayments) paidForMonth += p.amount;

      runningBalance = runningBalance + rentForMonth - paidForMonth;

      history.add({
        'month': month,
        'rent': rentForMonth,
        'paid': paidForMonth,
        'remaining': runningBalance,
      });
    }

    return history.reversed.toList();
  }

  // --- Final Cleanup ---
  Future<void> clearDatabase() async {
    try {
      setLoading(true);
      await http.delete(Uri.parse(_getUrl("shops")));
      await http.delete(Uri.parse(_getUrl("payments")));
      await http.delete(Uri.parse(_getUrl("rent_records")));
      await http.delete(Uri.parse(_getUrl("counters")));

      _shops.clear();
      _cachedRentRecords.clear();
      _cachedPayments.clear();
      _balances.clear();
      _totalDue = 0;
      _totalCollected = 0;
      _paidShopsCount = 0;
      _dataLoaded = false;

      notifyListeners();
    } catch (e) {
      print("Error clearing database: $e");
      rethrow;
    } finally {
      setLoading(false);
    }
  }
}

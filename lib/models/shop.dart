class Shop {
  final int id;
  final String shopName;
  final String shopkeeperName;
  final String contactNumber;
  final double monthlyRent;
  final String address;
  final double initialPreviousBalance;
  final double advancePayment;

  Shop({
    required this.id,
    required this.shopName,
    this.shopkeeperName = '',
    this.contactNumber = '',
    required this.monthlyRent,
    this.address = '',
    this.initialPreviousBalance = 0.0,
    this.advancePayment = 0.0,
  });

  factory Shop.fromJson(Map<String, dynamic> json) {
    return Shop(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      shopName: json['shop_name'] ?? '',
      shopkeeperName: json['shopkeeper_name'] ?? '',
      contactNumber: json['contact_number'] ?? '',
      monthlyRent: double.tryParse(json['monthly_rent'].toString()) ?? 0.0,
      address: json['address'] ?? '',
      initialPreviousBalance: double.tryParse(json['initial_previous_balance'].toString()) ?? 0.0,
      advancePayment: double.tryParse(json['advance_payment'].toString()) ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shop_name': shopName,
      'shopkeeper_name': shopkeeperName,
      'contact_number': contactNumber,
      'monthly_rent': monthlyRent,
      'address': address,
      'initial_previous_balance': initialPreviousBalance,
      'advance_payment': advancePayment,
    };
  }
}

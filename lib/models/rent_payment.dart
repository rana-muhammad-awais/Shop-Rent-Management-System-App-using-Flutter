class RentRecord {
  final int id;
  final int shopId;
  final String monthYear;
  final double rentAmount;
  final double previousBalance;
  final double totalDue;

  RentRecord({
    required this.id,
    required this.shopId,
    required this.monthYear,
    required this.rentAmount,
    this.previousBalance = 0.0,
    required this.totalDue,
  });

  factory RentRecord.fromJson(Map<String, dynamic> json) {
    return RentRecord(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      shopId: json['shop_id'] is int ? json['shop_id'] : int.parse(json['shop_id'].toString()),
      monthYear: json['month_year'] ?? '',
      rentAmount: double.tryParse(json['rent_amount'].toString()) ?? 0.0,
      previousBalance: double.tryParse(json['previous_balance'].toString()) ?? 0.0,
      totalDue: double.tryParse(json['total_due'].toString()) ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shop_id': shopId,
      'month_year': monthYear,
      'rent_amount': rentAmount,
      'previous_balance': previousBalance,
      'total_due': totalDue,
    };
  }
}

class Payment {
  final int id;
  final int shopId;
  final int? rentRecordId;
  final double amount;
  final String paymentDate;
  final String paymentMethod;
  final String notes;

  Payment({
    required this.id,
    required this.shopId,
    this.rentRecordId,
    required this.amount,
    required this.paymentDate,
    this.paymentMethod = '',
    this.notes = '',
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      shopId: json['shop_id'] is int ? json['shop_id'] : int.parse(json['shop_id'].toString()),
      rentRecordId: json['rent_record_id'] != null 
          ? (json['rent_record_id'] is int ? json['rent_record_id'] : int.parse(json['rent_record_id'].toString())) 
          : null,
      amount: double.tryParse(json['amount'].toString()) ?? 0.0,
      paymentDate: json['payment_date'] ?? '',
      paymentMethod: json['payment_method'] ?? '',
      notes: json['notes'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shop_id': shopId,
      'rent_record_id': rentRecordId,
      'amount': amount,
      'payment_date': paymentDate,
      'payment_method': paymentMethod,
      'notes': notes,
    };
  }
}

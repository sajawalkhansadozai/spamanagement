import 'package:cloud_firestore/cloud_firestore.dart';

class Customer {
  final String id;
  final String name;
  final String address;
  final String idCard;
  final String phone;
  final String category;
  final String service;
  final double amount; // Rs (can be negative when voided)
  final DateTime date;

  // NEW: soft-delete / audit
  final bool isVoided;
  final DateTime? voidedAt;
  final String? voidReason;

  Customer({
    required this.id,
    required this.name,
    required this.address,
    required this.idCard,
    required this.phone,
    required this.category,
    required this.service,
    required this.amount,
    required this.date,
    this.isVoided = false,
    this.voidedAt,
    this.voidReason,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'address': address,
      'idCard': idCard,
      'phone': phone,
      'category': category,
      'service': service,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'isVoided': isVoided,
      'voidedAt': voidedAt == null ? null : Timestamp.fromDate(voidedAt!),
      'voidReason': voidReason,
    };
    map.removeWhere((k, v) => v == null);
    return map;
  }

  factory Customer.fromMap(Map<String, dynamic> map, String id) {
    final rawDate = map['date'];
    DateTime parsedDate;
    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate is DateTime) {
      parsedDate = rawDate;
    } else {
      parsedDate = DateTime.now();
    }

    final rawVoidedAt = map['voidedAt'];
    DateTime? parsedVoidedAt;
    if (rawVoidedAt is Timestamp) parsedVoidedAt = rawVoidedAt.toDate();
    if (rawVoidedAt is DateTime) parsedVoidedAt = rawVoidedAt;

    return Customer(
      id: id,
      name: (map['name'] ?? '') as String,
      address: (map['address'] ?? '') as String,
      idCard: (map['idCard'] ?? '') as String,
      phone: (map['phone'] ?? '') as String,
      category: (map['category'] ?? '') as String,
      service: (map['service'] ?? '') as String,
      amount: (map['amount'] ?? 0).toDouble(),
      date: parsedDate,
      isVoided: (map['isVoided'] ?? false) as bool,
      voidedAt: parsedVoidedAt,
      voidReason: map['voidReason'] as String?,
    );
  }

  // Convenience for converter
  static Customer fromFirestore(Map<String, dynamic> data, String id) =>
      Customer.fromMap(data, id);
}

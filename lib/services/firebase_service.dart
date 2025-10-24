import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/customer.dart';

class FirebaseService {
  FirebaseService._();

  // Typed collection with converter <Customer>
  static final CollectionReference<Customer> _col = FirebaseFirestore.instance
      .collection('customers')
      .withConverter<Customer>(
        fromFirestore: (snap, _) =>
            Customer.fromMap(snap.data() ?? <String, dynamic>{}, snap.id),
        toFirestore: (c, _) => c.toMap(),
      );

  /// Create
  static Future<void> addCustomer(Customer customer) async {
    // ensure new records are non-void
    final c = Customer(
      id: customer.id,
      name: customer.name,
      address: customer.address,
      idCard: customer.idCard,
      phone: customer.phone,
      category: customer.category,
      service: customer.service,
      amount: customer.amount,
      date: customer.date,
      isVoided: false,
      voidedAt: null,
      voidReason: null,
    );
    await _col.add(c);
  }

  /// (Optional) Create and get the generated document id
  static Future<String> addCustomerGetId(Customer customer) async {
    final ref = await _col.add(customer);
    return ref.id;
  }

  /// Read (live) – optionally include voided
  static Stream<List<Customer>> getCustomers({bool includeVoided = true}) {
    Query<Customer> q = _col.orderBy('date', descending: true);
    if (!includeVoided) {
      q = q.where('isVoided', isEqualTo: false);
    }
    return q.snapshots().map((s) => s.docs.map((d) => d.data()).toList());
  }

  /// Read one by id
  static Future<Customer?> getCustomerById(String id) async {
    final snap = await _col.doc(id).get();
    return snap.data();
  }

  /// Read for a specific day (00:00 inclusive to next day 00:00 exclusive)
  /// Set [includeVoided] to true to include negative/void entries in results.
  static Future<List<Customer>> getCustomersForDate(
    DateTime date, {
    bool includeVoided = true,
  }) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final nextDay = startOfDay.add(const Duration(days: 1));

    Query<Customer> q = _col
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(nextDay))
        .orderBy('date', descending: true);

    if (!includeVoided) {
      q = q.where('isVoided', isEqualTo: false);
    }

    final snap = await q.get();
    return snap.docs.map((d) => d.data()).toList();
  }

  /// Read for a specific month (1st 00:00 inclusive to next month 1st 00:00 exclusive)
  static Future<List<Customer>> getCustomersForMonth(
    int year,
    int month, {
    bool includeVoided = true,
  }) async {
    final startOfMonth = DateTime(year, month, 1);
    final nextMonth = DateTime(year, month + 1, 1);

    Query<Customer> q = _col
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('date', isLessThan: Timestamp.fromDate(nextMonth))
        .orderBy('date', descending: true);

    if (!includeVoided) {
      q = q.where('isVoided', isEqualTo: false);
    }

    final snap = await q.get();
    return snap.docs.map((d) => d.data()).toList();
  }

  /// Read by category (optionally within a date range)
  static Future<List<Customer>> getCustomersByCategory({
    required String category,
    DateTime? start,
    DateTime? endExclusive,
    bool includeVoided = true,
  }) async {
    Query<Customer> q = _col.where('category', isEqualTo: category);

    if (start != null) {
      q = q.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start));
    }
    if (endExclusive != null) {
      q = q.where('date', isLessThan: Timestamp.fromDate(endExclusive));
    }
    if (!includeVoided) {
      q = q.where('isVoided', isEqualTo: false);
    }

    final snap = await q.orderBy('date', descending: true).get();
    return snap.docs.map((d) => d.data()).toList();
  }

  /// UPDATE (merge)
  static Future<void> updateCustomer(Customer c) async {
    await _col.doc(c.id).set(c, SetOptions(merge: true));
  }

  // ====== SOFT DELETE (VOID) ======
  /// Marks a customer entry as voided and flips amount negative.
  /// Keeps the original `date` so the reversal affects the same day/month totals.
  static Future<void> voidCustomer(String id, {String? reason}) async {
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final docRef = _col.doc(id);
      final snap = await tx.get(docRef);
      final data = snap.data();
      if (data == null) {
        throw Exception('Customer not found');
      }

      final negAmount = -data.amount.abs();

      tx.update(docRef, {
        'amount': negAmount,
        'isVoided': true,
        'voidedAt': Timestamp.now(),
        if (reason != null && reason.trim().isNotEmpty)
          'voidReason': reason.trim(),
      });
    });
  }

  /// DEPRECATED: Hard delete. Prefer [voidCustomer] for audit trail.
  static Future<void> deleteCustomer(String id) async {
    // By default, perform a soft delete for safety:
    await voidCustomer(id, reason: 'Voided via deleteCustomer()');
    // If you truly need to hard-delete, uncomment the next line:
    // await _col.doc(id).delete();
  }

  // =========================
  // RETURNS (negative sales)
  // =========================

  /// Creates a **separate** negative record to represent a return.
  /// - Uses the original record's `date` so daily/monthly aggregates adjust correctly.
  /// - Keeps the original sale intact (for audit trail).
  /// - If [amount] is null, returns the full original amount.
  static Future<void> recordReturn({
    required Customer original,
    double? amount,
  }) async {
    final double returnAmount = (amount ?? original.amount).abs();
    if (returnAmount <= 0) {
      throw ArgumentError('Return amount must be greater than zero.');
    }
    if (returnAmount > original.amount.abs()) {
      throw ArgumentError('Return amount cannot exceed original amount.');
    }

    // Build a new negative row; keep schema identical to Customer
    final Customer neg = Customer(
      id: '', // let Firestore generate a new id
      name: original.name,
      address: original.address,
      idCard: original.idCard,
      phone: original.phone,
      category: original.category,
      // Helpful label; harmless if you later add explicit flags to the model
      service: 'RETURN — ${original.service}',
      amount: -returnAmount, // NEGATIVE
      date: original.date, // 👈 keep same day as original
      isVoided: false, // this is a valid (non-void) record
      voidedAt: null,
      voidReason: null,
    );

    await _col.add(neg);
  }

  /// Convenience: record a return by original doc id.
  static Future<void> recordReturnById(String id, {double? amount}) async {
    final original = await getCustomerById(id);
    if (original == null) {
      throw Exception('Customer not found');
    }
    await recordReturn(original: original, amount: amount);
  }
}

/// Dashboard aggregates
///
/// Sales == sum of all amounts (positives + negatives)
/// Counts == number of *non-voided* positive rows (so voids don’t inflate counts)
class SpaStats {
  static Future<Map<String, dynamic>> getDashboardStats() async {
    final now = DateTime.now();

    // Day range
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrow = todayStart.add(const Duration(days: 1));

    // Month range
    final monthStart = DateTime(now.year, now.month, 1);
    final nextMonth = DateTime(now.year, now.month + 1, 1);

    // Today (include voided so sales can include negatives)
    final todaySnap = await FirebaseService._col
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
        .where('date', isLessThan: Timestamp.fromDate(tomorrow))
        .orderBy('date', descending: true)
        .get();
    final todayCustomers = todaySnap.docs.map((d) => d.data()).toList();

    // This month (include voided so sales can include negatives)
    final monthSnap = await FirebaseService._col
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
        .where('date', isLessThan: Timestamp.fromDate(nextMonth))
        .orderBy('date', descending: true)
        .get();
    final monthCustomers = monthSnap.docs.map((d) => d.data()).toList();

    // Recent 5 (any state)
    final recentSnap = await FirebaseService._col
        .orderBy('date', descending: true)
        .limit(5)
        .get();
    final recentCustomers = recentSnap.docs.map((d) => d.data()).toList();

    // Aggregates:
    // sales include negatives; counts exclude voided rows
    final todaySales = todayCustomers.fold<double>(0.0, (s, c) => s + c.amount);
    final monthSales = monthCustomers.fold<double>(0.0, (s, c) => s + c.amount);

    final todayCount = todayCustomers
        .where((c) => !c.isVoided && c.amount > 0)
        .length;
    final monthCount = monthCustomers
        .where((c) => !c.isVoided && c.amount > 0)
        .length;

    return {
      'todayCustomers': todayCount,
      'todaySales': todaySales,
      'monthCustomers': monthCount,
      'monthSales': monthSales,
      'recentCustomers': recentCustomers,
    };
  }
}

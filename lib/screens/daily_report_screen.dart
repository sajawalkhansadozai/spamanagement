import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/customer.dart';
import '../services/firebase_service.dart';

class DailyReportScreen extends StatefulWidget {
  final DateTime selectedDate;
  const DailyReportScreen({super.key, required this.selectedDate});

  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen> {
  DateTime _date = DateTime.now();
  late Future<List<Customer>> _future;

  final _search = TextEditingController();
  String _query = '';

  // Category chip selection
  String _selectedCategory = 'All';

  // ----- Helpers -----
  String _fmtRs(num v) => 'Rs.${v.toStringAsFixed(2)}';
  String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  /// Non-null, trimmed string. Safe to pass to Text widgets.
  String _nz(String? s) => (s ?? '').trim();

  /// Normalize category to a non-null stable label.
  String _cat(Customer c) {
    final v = _nz(c.category);
    return v.isEmpty ? 'Uncategorized' : v;
  }

  @override
  void initState() {
    super.initState();
    _date = widget.selectedDate;
    _future = FirebaseService.getCustomersForDate(_date);

    _search.addListener(() {
      setState(() => _query = _search.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = FirebaseService.getCustomersForDate(_date);
    });
    await _future;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: Colors.teal.shade600,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Colors.grey.shade800,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _date) {
      setState(() {
        _date = picked;
        _future = FirebaseService.getCustomersForDate(_date);
      });
    }
  }

  Future<void> _onReturnPressed(Customer original) async {
    final controller = TextEditingController(
      text: original.amount.toStringAsFixed(2),
    );
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Record Return'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Customer: ${_nz(original.name)}\n'
                'Service: ${_nz(original.service)}\n'
                'Original: ${_fmtRs(original.amount)}',
                style: const TextStyle(height: 1.3),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Return amount',
                  hintText: 'e.g. 1500.00',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: false,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Amount is required';
                  }
                  final parsed = double.tryParse(v);
                  if (parsed == null) return 'Enter a valid number';
                  if (parsed <= 0) return 'Must be greater than zero';
                  if (parsed > original.amount) {
                    return 'Cannot exceed original amount';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.undo_rounded),
            label: const Text('Record Return'),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final amt = double.parse(controller.text);
              try {
                await FirebaseService.recordReturn(
                  original: original,
                  amount: amt,
                );
                if (context.mounted) Navigator.pop(context, true);
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to record return: $e')),
                );
              }
            },
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Return recorded')));
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refresh,
        color: Colors.teal,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 16),
          child: _ResponsiveCenter(
            child: FutureBuilder<List<Customer>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _errorBox('Failed to load daily report.');
                }

                if (!snapshot.hasData) {
                  return Column(
                    children: [const SizedBox(height: 16), _loading()],
                  );
                }

                // ============ Data + Normalization ============
                final allRaw = snapshot.data!;
                // Normalize: every string field we might show becomes non-null.
                final all = allRaw
                    .map(
                      (c) => _NormalizedCustomer(
                        name: _nz(c.name),
                        phone: _nz(c.phone),
                        service: _nz(c.service),
                        address: _nz(c.address),
                        category: _cat(c),
                        amount: c.amount,
                        date: c.date,
                        original: c,
                      ),
                    )
                    .toList();

                // Build categories from ALL data
                final Set<String> allCats = {for (final c in all) c.category};
                var categoryOrder = _orderedCategoryKeys(allCats);
                final List<String> categories = ['All', ...categoryOrder];

                if (!categories.contains(_selectedCategory)) {
                  _selectedCategory = 'All';
                }

                // Category filter
                Iterable<_NormalizedCustomer> working = all;
                if (_selectedCategory != 'All') {
                  working = working.where(
                    (c) => c.category == _selectedCategory,
                  );
                }

                // Search filter
                final filtered = _query.isEmpty
                    ? working.toList()
                    : working.where((c) {
                        final q = _query;
                        return c.nameL.contains(q) ||
                            c.phoneL.contains(q) ||
                            c.serviceL.contains(q) ||
                            c.categoryL.contains(q);
                      }).toList();

                final dayTotal = filtered.fold<double>(
                  0,
                  (s, c) => s + c.amount,
                );

                // Group filtered by category
                final groups = _groupByCategory(filtered);
                categoryOrder = _orderedCategoryKeys(groups.keys.toSet());

                final categoryTotals = {
                  for (final k in categoryOrder)
                    k: groups[k]!.fold<double>(0, (s, c) => s + c.amount),
                };

                // ================= UI =================
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 8),

                    ReportHeaderBar(
                      icon: Icons.calendar_today_rounded,
                      title: 'Daily Report',
                      subtitle: _formatDate(_date),
                      colors: [Colors.teal.shade600, Colors.teal.shade800],
                      accentGlow: Colors.tealAccent.withOpacity(0.35),
                    ),

                    const SizedBox(height: 12),

                    // Date selector
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _pickDate,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.teal.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.event_rounded,
                                  color: Colors.teal.shade600,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Selected Date',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      DateFormat(
                                        'EEEE, MMM dd, yyyy',
                                      ).format(_date),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.grey.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.indigo.shade50,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_month_rounded,
                                      size: 16,
                                      color: Colors.indigo.shade700,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Change',
                                      style: TextStyle(
                                        color: Colors.indigo.shade700,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Search + Category chips
                    _SearchField(controller: _search),
                    const SizedBox(height: 10),
                    _CategoryChips(
                      categories: categories,
                      selected: _selectedCategory,
                      onSelected: (v) => setState(() => _selectedCategory = v),
                    ),

                    const SizedBox(height: 16),

                    // Stats
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final available = constraints.maxWidth;
                        final isTiny = available < 360;
                        final raw = available > 0
                            ? (available - 12) / 2
                            : 160.0;
                        final tileW = raw.clamp(140.0, 480.0).toDouble();

                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: isTiny ? available : tileW,
                              child: AnimatedStatCard(
                                title: 'Records',
                                value: filtered.length.toDouble(),
                                format: (v) => v.toStringAsFixed(0),
                                icon: Icons.people_alt_rounded,
                                colors: [
                                  Colors.red.shade400,
                                  Colors.red.shade600,
                                ],
                              ),
                            ),
                            SizedBox(
                              width: isTiny ? available : tileW,
                              child: AnimatedStatCard(
                                title: 'Net Sales',
                                value: dayTotal,
                                format: (v) => _fmtRs(v),
                                icon: Icons.trending_up_rounded,
                                colors: [
                                  Colors.teal.shade400,
                                  Colors.teal.shade600,
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    // Category subtotals
                    _buildCategorySummary(categoryTotals),

                    const SizedBox(height: 20),

                    // Per-category sections
                    if (filtered.isNotEmpty)
                      ...categoryOrder.map(
                        (cat) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: _buildCategorySection(
                            category: cat,
                            customers: groups[cat]!,
                            subtotal: categoryTotals[cat] ?? 0,
                          ),
                        ),
                      )
                    else
                      _buildEmptyState(),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Empty state ----------
  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.grey.shade100, Colors.grey.shade200],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.event_busy_rounded,
              size: 44,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No Records',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'No transactions recorded for ${_formatDate(_date)}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Grouping & ordering ----------
  Map<String, List<_NormalizedCustomer>> _groupByCategory(
    List<_NormalizedCustomer> list,
  ) {
    final map = <String, List<_NormalizedCustomer>>{};
    for (final c in list) {
      map.putIfAbsent(c.category, () => []).add(c);
    }
    return map;
  }

  List<String> _orderedCategoryKeys(Set<String> keys) {
    const preferred = [
      'Ladies Salon',
      'Men Salon',
      'Indoor Swimming Pool',
      'Gym',
      'Uncategorized',
    ];
    final remaining = keys.where((k) => !preferred.contains(k)).toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return [...preferred.where(keys.contains), ...remaining];
  }

  // ---------- Summary tiles ----------
  Widget _buildCategorySummary(Map<String, double> totals) {
    if (totals.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final isPhone = w < 480;
        final tileW = isPhone
            ? w
            : ((w - 12) / 2).clamp(180.0, 480.0).toDouble();

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: totals.entries.map((e) {
            final isNeg = e.value < 0;
            return SizedBox(
              width: tileW,
              child: AnimatedStatCard(
                title: '${e.key} — Subtotal',
                value: e.value,
                format: (v) => _fmtRs(v),
                icon: Icons.pie_chart_rounded,
                colors: isNeg
                    ? [Colors.red.shade400, Colors.red.shade700]
                    : [Colors.teal.shade400, Colors.teal.shade700],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ---------- Category section ----------
  Widget _buildCategorySection({
    required String category,
    required List<_NormalizedCustomer> customers,
    required double subtotal,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashFactory: InkRipple.splashFactory,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          initiallyExpanded: true,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.indigo.shade500, Colors.indigo.shade700],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.category_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _subtotalPill(subtotal, customers.length),
            ],
          ),
          children: [
            Column(
              children: customers.asMap().entries.map((entry) {
                final index = entry.key;
                final c = entry.value;
                final isLast = index == customers.length - 1;

                String _initial(String name) =>
                    name.isEmpty ? '?' : name.characters.first.toUpperCase();

                final svcUpper = c.service.toUpperCase();
                final isReturn = c.amount < 0 || svcUpper.startsWith('RETURN');

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isReturn ? Colors.red.shade50 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isReturn
                          ? Colors.red.shade100
                          : Colors.grey.shade200,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isReturn
                                    ? [Colors.red.shade400, Colors.red.shade600]
                                    : [
                                        Colors.teal.shade300,
                                        Colors.teal.shade500,
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                _initial(c.name),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(
                              minWidth: 120,
                              maxWidth: 420,
                            ),
                            child: Text(
                              isReturn ? '${c.name} (Return)' : c.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey.shade900,
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _fmtTime(c.date),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isReturn
                                    ? [Colors.red.shade400, Colors.red.shade700]
                                    : [
                                        Colors.green.shade400,
                                        Colors.green.shade600,
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _fmtRs(c.amount),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                          if (!isReturn)
                            OutlinedButton.icon(
                              icon: const Icon(Icons.undo_rounded, size: 18),
                              label: const Text('Return'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade700,
                                side: BorderSide(color: Colors.red.shade300),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                              ),
                              onPressed: () => _onReturnPressed(c.original),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _chip(
                            icon: isReturn
                                ? Icons.undo_rounded
                                : Icons.spa_rounded,
                            text: isReturn
                                ? 'RETURN — ${c.service}'
                                : c.service,
                            bg: isReturn
                                ? Colors.red.shade100
                                : Colors.purple.shade50,
                            fg: isReturn
                                ? Colors.red.shade800
                                : Colors.purple.shade700,
                            iconColor: isReturn
                                ? Colors.red.shade700
                                : Colors.purple.shade600,
                          ),
                          if (c.phone.isNotEmpty)
                            _chip(
                              icon: Icons.phone_rounded,
                              text: c.phone,
                              bg: Colors.indigo.shade50,
                              fg: Colors.indigo.shade700,
                              iconColor: Colors.indigo.shade600,
                            ),
                          if (c.address.isNotEmpty)
                            _chip(
                              icon: Icons.location_pin,
                              text: c.address,
                              bg: Colors.grey.shade100,
                              fg: Colors.grey.shade800,
                              iconColor: Colors.grey.shade700,
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _subtotalPill(double subtotal, int count) {
    final neg = subtotal < 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (neg ? Colors.red : Colors.green).withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (neg ? Colors.red : Colors.green).withOpacity(0.25),
        ),
      ),
      child: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(
            neg ? Icons.trending_down_rounded : Icons.trending_up_rounded,
            size: 16,
            color: neg ? Colors.red : Colors.green,
          ),
          Text(
            _fmtRs(subtotal),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: neg ? Colors.red.shade700 : Colors.green.shade700,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
          Text(
            '• $count',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBox(String msg) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.red.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loading() => Column(
    children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.teal.withOpacity(0.1),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
            strokeWidth: 3,
          ),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'Loading daily report...',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );

  Widget _chip({
    required IconData icon,
    required String text,
    required Color bg,
    required Color fg,
    required Color iconColor,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text, // already non-null
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

/// Small view-model with guaranteed non-null strings for the UI.
class _NormalizedCustomer {
  final String name;
  final String phone;
  final String service;
  final String address;
  final String category;
  final String nameL;
  final String phoneL;
  final String serviceL;
  final String categoryL;
  final double amount;
  final DateTime date;

  /// Original model to pass back into service calls (e.g., recordReturn)
  final Customer original;

  _NormalizedCustomer({
    required this.name,
    required this.phone,
    required this.service,
    required this.address,
    required this.category,
    required this.amount,
    required this.date,
    required this.original,
  }) : nameL = name.toLowerCase(),
       phoneL = phone.toLowerCase(),
       serviceL = service.toLowerCase(),
       categoryL = category.toLowerCase();
}

/// Reusable header bar
class ReportHeaderBar extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final Color accentGlow;

  const ReportHeaderBar({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.accentGlow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
        boxShadow: [
          BoxShadow(
            color: colors.last.withOpacity(0.30),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: accentGlow,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: accentGlow, blurRadius: 12, spreadRadius: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  const _SearchField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search by name, phone, service, or category',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => controller.clear(),
                  ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.teal, width: 1.2),
            ),
          ),
        );
      },
    );
  }
}

class _CategoryChips extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: categories.map((cat) {
          final sel = cat == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(cat, overflow: TextOverflow.ellipsis),
              selected: sel,
              onSelected: (_) => onSelected(cat),
              labelStyle: TextStyle(
                fontWeight: FontWeight.w700,
                color: sel ? Colors.white : Colors.grey.shade800,
              ),
              selectedColor: Colors.teal.shade600,
              backgroundColor: Colors.white,
              side: BorderSide(
                color: sel ? Colors.teal.shade700 : Colors.grey.shade300,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class AnimatedStatCard extends StatelessWidget {
  final String title;
  final double value;
  final String Function(double) format;
  final IconData icon;
  final List<Color> colors;

  const AnimatedStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.format,
    required this.icon,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 14,
        vertical: isMobile ? 12 : 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: isMobile ? 34 : 36,
            height: isMobile ? 34 : 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: isMobile ? 18 : 18, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: isMobile ? 12 : 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: value),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOut,
                  builder: (_, v, __) => Text(
                    format(v),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade900,
                      fontSize: isMobile ? 18 : 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResponsiveCenter extends StatelessWidget {
  final Widget child;
  const _ResponsiveCenter({required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final w = constraints.maxWidth;
        final maxW = w < 600 ? w : (w < 1024 ? 700.0 : 900.0);
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

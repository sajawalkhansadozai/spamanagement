import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/customer.dart';
import '../services/firebase_service.dart';
import '../widgets/ui_components.dart'; // uses GradientCard

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _fmtRs(num v) =>
      'Rs.${NumberFormat.decimalPattern('en_IN').format(v)}';

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,

      // ===== Branded Top Bar =====
      appBar: _RahizTopBar(
        businessName: 'Rahiz Spa and Salon',
        pageTitle: 'Spa Management Dashboard',
      ),

      body: StreamBuilder<List<Customer>>(
        stream: FirebaseService.getCustomers(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(
                    'Loading dashboard...',
                    style: TextStyle(
                      color: Colors.teal.shade600,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          final allCustomers = snapshot.data!;
          final todayCustomers = allCustomers
              .where(
                (c) =>
                    c.date.day == today.day &&
                    c.date.month == today.month &&
                    c.date.year == today.year,
              )
              .toList();

          final monthCustomers = allCustomers
              .where(
                (c) => c.date.month == today.month && c.date.year == today.year,
              )
              .toList();

          final todaySales = todayCustomers.fold<double>(
            0,
            (s, c) => s + c.amount,
          );
          final monthlySales = monthCustomers.fold<double>(
            0,
            (s, c) => s + c.amount,
          );

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  // Header card (responsive width + centered)
                  _ResponsiveCenter(
                    child: GradientCard(
                      colors: [
                        Colors.teal.shade200,
                        Colors.teal.shade500,
                        Colors.teal.shade700,
                      ],
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.spa_rounded,
                              size: 48,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Welcome to Spa Management',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              DateFormat('EEEE, MMM dd, yyyy').format(today),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Compact stats grid (responsive)
                  _ResponsiveCenter(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final cols = constraints.maxWidth >= 420 ? 2 : 1;
                        const gap = 12.0;
                        final tileWidth =
                            (constraints.maxWidth - gap * (cols - 1)) / cols;

                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            SizedBox(
                              width: tileWidth,
                              child: MiniStatCard(
                                title: "Today's Customers",
                                value: '${todayCustomers.length}',
                                icon: Icons.people_rounded,
                                colors: [
                                  Colors.blue.shade400,
                                  Colors.blue.shade600,
                                ],
                              ),
                            ),
                            SizedBox(
                              width: tileWidth,
                              child: MiniStatCard(
                                title: "Today's Sales",
                                value: _fmtRs(todaySales),
                                icon: Icons.attach_money_rounded,
                                colors: [
                                  Colors.green.shade400,
                                  Colors.green.shade600,
                                ],
                              ),
                            ),
                            SizedBox(
                              width: tileWidth,
                              child: MiniStatCard(
                                title: 'Monthly Customers',
                                value: '${monthCustomers.length}',
                                icon: Icons.calendar_month_rounded,
                                colors: [
                                  Colors.orange.shade400,
                                  Colors.orange.shade600,
                                ],
                              ),
                            ),
                            SizedBox(
                              width: tileWidth,
                              child: MiniStatCard(
                                title: 'Monthly Sales',
                                value: _fmtRs(monthlySales),
                                icon: Icons.trending_up_rounded,
                                colors: [
                                  Colors.purple.shade400,
                                  Colors.purple.shade600,
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Recent Customers (responsive)
                  _ResponsiveCenter(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.shade50,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    Icons.history_rounded,
                                    color: Colors.teal.shade600,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Recent Customers',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (allCustomers.isEmpty)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 24,
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.people_outline_rounded,
                                        size: 56,
                                        color: Colors.grey.shade300,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No customers yet',
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              Column(
                                children: allCustomers.take(5).map((customer) {
                                  final isReturn = customer.amount < 0;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                        width: 1,
                                      ),
                                    ),
                                    child: Wrap(
                                      spacing: 12,
                                      runSpacing: 8,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        // Avatar
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.teal.shade300,
                                                Colors.teal.shade500,
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: const Center(
                                            child: Icon(
                                              Icons.person_rounded,
                                              color: Colors.white,
                                              size: 22,
                                            ),
                                          ),
                                        ),
                                        // Name + service (flex)
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            minWidth: 120,
                                            maxWidth: 420,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                customer.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                  color: Colors.grey.shade800,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                customer.service,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Amount (red if return, green if sale)  <<< UPDATED
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isReturn
                                                ? Colors.red.shade50
                                                : Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Text(
                                            _fmtRs(customer.amount),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: isReturn
                                                  ? Colors.red.shade700
                                                  : Colors.green.shade700,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Compact stat tile with mobile-friendly sizing.
class MiniStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final List<Color> colors;

  const MiniStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final isMobile = w < 600;
    final iconBg = [colors.first, colors.last];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 14,
        vertical: isMobile ? 12 : 12,
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
              gradient: LinearGradient(colors: iconBg),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(icon, size: isMobile ? 18 : 18, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
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
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade900,
                    fontSize: isMobile ? 18 : 18,
                    fontWeight: FontWeight.w800,
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

/// Responsive centered container:
/// - phones: full width
/// - tablets: ~700px
/// - desktop: 900px
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

// ===================== Custom Branded App Bar =====================
class _RahizTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String businessName;
  final String pageTitle;

  const _RahizTopBar({required this.businessName, required this.pageTitle});

  @override
  Size get preferredSize => const Size.fromHeight(98);

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEE, d MMM y').format(DateTime.now());

    return PreferredSize(
      preferredSize: preferredSize,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.teal.shade500,
              Colors.teal.shade600,
              Colors.indigo.shade600,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
            child: Row(
              children: [
                // Monogram box
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.18)),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'RS',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Titles
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        businessName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              pageTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.96),
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_month_rounded,
                                  size: 16,
                                  color: Colors.white.withOpacity(0.95),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  dateStr,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.95),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),
                Tooltip(
                  message: 'Refresh',
                  waitDuration: const Duration(milliseconds: 400),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        // StreamBuilder auto-updates; no manual refresh needed.
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.refresh_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Live',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

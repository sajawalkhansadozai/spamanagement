import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../models/customer.dart';
import '../services/firebase_service.dart';

class PrintReportsScreen extends StatelessWidget {
  final DateTime selectedDate;
  PrintReportsScreen({super.key, required this.selectedDate});

  // ===== Helpers =====
  String _rs(num v) => 'Rs.${NumberFormat('#,##0.00').format(v)}';
  final _dateDay = DateFormat('dd/MM/yyyy');
  final _dateMonth = DateFormat('MMMM yyyy');
  final _dateTime = DateFormat('dd/MM/yyyy HH:mm');

  Future<void> _printDailyReport(BuildContext context) async {
    try {
      final customers = await FirebaseService.getCustomersForDate(selectedDate);
      final total = customers.fold<double>(0, (s, c) => s + c.amount);

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          ),
          header: (c) => _pdfHeader(
            title: 'Daily Report',
            subtitle: _dateDay.format(selectedDate),
          ),
          footer: (c) => _pdfFooter(page: c.pageNumber, pages: c.pagesCount),
          build: (context) => [
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _statBox('Total Customers', customers.length.toString()),
                _statBox('Total Sales', _rs(total)),
              ],
            ),
            pw.SizedBox(height: 16),

            pw.Text(
              'Customer Details',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),

            pw.TableHelper.fromTextArray(
              headers: const ['Name', 'Service', 'Amount'],
              data: customers.map((c) {
                return [c.name, c.service, _rs(c.amount)];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellAlignment: pw.Alignment.centerLeft,
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(1),
              },
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerRight,
              },
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey300),
                ),
              ),
            ),

            pw.SizedBox(height: 16),
            pw.Divider(),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Total Sales for the day: ${_rs(total)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
      _ok(context, 'Daily report sent to printer.');
    } catch (e) {
      _err(context, 'Failed to print daily report: $e');
    }
  }

  Future<void> _printMonthlyReport(BuildContext context) async {
    try {
      final customers = await FirebaseService.getCustomersForMonth(
        selectedDate.year,
        selectedDate.month,
      );

      final total = customers.fold<double>(0, (s, c) => s + c.amount);
      final avg = customers.isNotEmpty ? (total / customers.length) : 0.0;

      final Map<String, List<Customer>> serviceGroups = {};
      for (final c in customers) {
        serviceGroups.putIfAbsent(c.service, () => []).add(c);
      }

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          ),
          header: (c) => _pdfHeader(
            title: 'Monthly Report',
            subtitle: _dateMonth.format(selectedDate),
          ),
          footer: (c) => _pdfFooter(page: c.pageNumber, pages: c.pagesCount),
          build: (context) => [
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _statBox('Total Customers', customers.length.toString()),
                _statBox('Total Sales', _rs(total)),
                _statBox('Avg / Customer', _rs(avg)),
              ],
            ),
            pw.SizedBox(height: 16),

            pw.Text(
              'Service Breakdown',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: const ['Service', 'Customers', 'Total'],
              data:
                  serviceGroups.entries.map((e) {
                    final service = e.key;
                    final count = e.value.length;
                    final sum = e.value.fold<double>(0, (s, c) => s + c.amount);
                    return [service, '$count', _rs(sum)];
                  }).toList()..sort(
                    (a, b) => double.parse(
                      b[2].replaceAll('Rs.', ''),
                    ).compareTo(double.parse(a[2].replaceAll('Rs.', ''))),
                  ),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellStyle: const pw.TextStyle(fontSize: 10),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(2),
              },
              cellAlignments: const {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerRight,
              },
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey300),
                ),
              ),
            ),

            pw.SizedBox(height: 16),
            pw.Divider(),
            pw.Align(
              alignment: pw.Alignment.center,
              child: pw.Text(
                'Generated on ${_dateTime.format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ),
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
      _ok(context, 'Monthly report sent to printer.');
    } catch (e) {
      _err(context, 'Failed to print monthly report: $e');
    }
  }

  // ===== PDF helpers =====
  pw.Widget _pdfHeader({required String title, required String subtitle}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          'SPA MANAGEMENT',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 0.2,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text('$title — $subtitle', style: const pw.TextStyle(fontSize: 11)),
        pw.SizedBox(height: 8),
        pw.Divider(),
      ],
    );
  }

  pw.Widget _pdfFooter({required int page, required int pages}) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Text(
        'Page $page of $pages',
        style: const pw.TextStyle(fontSize: 10),
      ),
    );
  }

  pw.Widget _statBox(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal.shade600, Colors.teal.shade800],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.print_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          "Print Reports",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.tealAccent,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.tealAccent.withOpacity(0.8),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: _ResponsiveCenter(
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Print Options',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 16),

                // Card with two actions
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _ReportTile(
                        color: Colors.blue,
                        icon: Icons.today_rounded,
                        title: 'Print Daily Report',
                        subtitle:
                            'Generate report for ${_dateDay.format(selectedDate)}',
                        onTap: () => _printDailyReport(context),
                        top: true,
                      ),
                      Divider(height: 1, color: Colors.grey.shade200),
                      _ReportTile(
                        color: Colors.green,
                        icon: Icons.calendar_month_rounded,
                        title: 'Print Monthly Report',
                        subtitle:
                            'Generate report for ${_dateMonth.format(selectedDate)}',
                        onTap: () => _printMonthlyReport(context),
                        bottom: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _ok(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _err(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

// ===== Small responsive pieces =====

class _ReportTile extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool top;
  final bool bottom;

  const _ReportTile({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.top = false,
    this.bottom = false,
  });

  @override
  Widget build(BuildContext context) {
    final shade50 = color.withOpacity(0.10);
    final shade600 = color;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: shade600),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey.shade600),
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(top ? 16 : 0),
          topRight: Radius.circular(top ? 16 : 0),
          bottomLeft: Radius.circular(bottom ? 16 : 0),
          bottomRight: Radius.circular(bottom ? 16 : 0),
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      minLeadingWidth: 0,
      horizontalTitleGap: 12,
    );
  }
}

/// Responsive centered container:
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
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

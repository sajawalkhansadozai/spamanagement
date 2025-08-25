import 'dart:ui';
import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'add_customer_screen.dart';
import 'daily_report_screen.dart';
import 'monthly_report_screen.dart';
import 'print_reports_screen.dart';

class DashboardScreen extends StatefulWidget {
  /// which tab to open first (0=Home, 1=Add, 2=Daily, 3=Monthly)
  final int startIndex;
  const DashboardScreen({super.key, this.startIndex = 0});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late int _currentIndex;

  // Use IndexedStack to preserve state of each tab
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const HomeScreen(),
      const AddCustomerScreen(),
      DailyReportScreen(selectedDate: DateTime.now()),
      MonthlyReportScreen(selectedDate: DateTime.now()),
    ];
    _currentIndex = widget.startIndex.clamp(0, _screens.length - 1);
  }

  void _openPrintScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PrintReportsScreen(selectedDate: DateTime.now()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: _screens),

      // Floating Print button
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'print-fab',
        onPressed: _openPrintScreen,
        icon: const Icon(Icons.print_rounded),
        label: const Text('Print'),
        tooltip: 'Open Print Reports',
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      // Glow Glass NavBar
      bottomNavigationBar: GlowGlassNavBar(
        currentIndex: _currentIndex,
        items: const [
          NavItemData(icon: Icons.home_rounded, label: 'Home'),
          NavItemData(icon: Icons.person_add_rounded, label: 'Add Customer'),
          NavItemData(icon: Icons.today_rounded, label: 'Daily Report'),
          NavItemData(icon: Icons.calendar_month_rounded, label: 'Monthly'),
        ],
        onChanged: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

/// Simple data holder
class NavItemData {
  final IconData icon;
  final String label;
  const NavItemData({required this.icon, required this.label});
}

/// A polished, glassy bottom bar with an animated highlight pill and soft icon glow.
/// - Overflow-proof (wraps labels away on tiny widths)
/// - Compact mode (icons-only) on very narrow screens
/// - Uses BackdropFilter for the frosted glass effect
class GlowGlassNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onChanged;
  final List<NavItemData> items;

  const GlowGlassNavBar({
    super.key,
    required this.currentIndex,
    required this.onChanged,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;

          // Breakpoints
          final isTiny = w < 340; // very small phones / split view
          final isCompact = w < 420; // small phones / landscape phones

          final barHeight = isTiny ? 58.0 : (isCompact ? 64.0 : 72.0);
          final iconSize = isTiny ? 20.0 : 22.0;
          final showLabels = !isCompact;

          // A subtle top divider glow
          final topStroke = cs.onSurface.withOpacity(0.08);

          return ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  // glassy gradient backdrop
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      cs.surface.withOpacity(0.70),
                      cs.surfaceVariant.withOpacity(0.55),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.10),
                      blurRadius: 26,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: SizedBox(
                  height: barHeight,
                  child: CustomPaint(
                    painter: _TopDividerPainter(color: topStroke),
                    child: Row(
                      children: List.generate(items.length, (i) {
                        final selected = i == currentIndex;
                        return Expanded(
                          child: _NavCapsuleButton(
                            data: items[i],
                            selected: selected,
                            onTap: () => onChanged(i),
                            showLabel: showLabels,
                            iconSize: iconSize,
                            // Colors for the moving “pill”
                            pillStart: cs.primaryContainer,
                            pillEnd: Color.alphaBlend(
                              cs.primary.withOpacity(0.10),
                              cs.primaryContainer,
                            ),
                            textColor: cs.onPrimaryContainer,
                            unselectedColor: cs.onSurface.withOpacity(0.64),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Adds a 1px soft divider on top (inside the bar)
class _TopDividerPainter extends CustomPainter {
  final Color color;
  const _TopDividerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    canvas.drawLine(const Offset(0, 0.5), Offset(size.width, 0.5), p);
  }

  @override
  bool shouldRepaint(covariant _TopDividerPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _NavCapsuleButton extends StatelessWidget {
  final NavItemData data;
  final bool selected;
  final VoidCallback onTap;

  // Styling
  final bool showLabel;
  final double iconSize;
  final Color pillStart;
  final Color pillEnd;
  final Color textColor;
  final Color unselectedColor;

  const _NavCapsuleButton({
    required this.data,
    required this.selected,
    required this.onTap,
    required this.showLabel,
    required this.iconSize,
    required this.pillStart,
    required this.pillEnd,
    required this.textColor,
    required this.unselectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final capsule = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.fastOutSlowIn,
      padding: EdgeInsets.symmetric(
        horizontal: selected && showLabel ? 14 : 0,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: selected
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [pillStart, pillEnd],
              )
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _IconGlow(
            glow: selected,
            child: Icon(
              data.icon,
              size: iconSize,
              color: selected ? textColor : unselectedColor,
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.fastOutSlowIn,
            switchOutCurve: Curves.fastOutSlowIn,
            child: (selected && showLabel)
                ? Padding(
                    key: const ValueKey('label'),
                    padding: const EdgeInsets.only(left: 8),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Text(
                        data.label,
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('nolabel')),
          ),
        ],
      ),
    );

    return Semantics(
      selected: selected,
      label: data.label,
      button: true,
      child: Tooltip(
        message: data.label,
        waitDuration: const Duration(milliseconds: 450),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            splashColor: Colors.white.withOpacity(0.08),
            highlightColor: Colors.white.withOpacity(0.06),
            child: capsule,
          ),
        ),
      ),
    );
  }
}

/// Soft glow around selected icon + subtle scale-in for feedback
class _IconGlow extends StatelessWidget {
  final Widget child;
  final bool glow;
  const _IconGlow({required this.child, required this.glow});

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 180),
      scale: glow ? 1.0 : 0.98,
      curve: Curves.easeOut,
      child: DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: glow
              ? [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.25),
                    blurRadius: 12,
                    spreadRadius: 1.5,
                  ),
                ]
              : const [],
        ),
        child: child,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'dart:ui' as ui;

void main() {
  runApp(const DemoApp());
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Half-Centered Widgets Demo (No Animations)',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        fontFamily: 'Roboto',
      ),
      home: const DemoPage(),
    );
  }
}

/// A wrapper that centers its child and makes it take half the screen width.
class HalfCenter extends StatelessWidget {
  final Widget child;
  final double widthFactor;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  const HalfCenter({
    super.key,
    required this.child,
    this.widthFactor = 0.5,
    this.maxWidth = 520,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final targetWidth = (w * widthFactor).clamp(280.0, maxWidth);

    return Center(
      child: Padding(
        padding: padding,
        child: SizedBox(width: targetWidth, child: child),
      ),
    );
  }
}

/// =================== Demo Page ===================
class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HalfCenter(
                child: GradientCard(
                  onTap: () {},
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'GradientCard',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Half width • Centered',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              HalfCenter(
                child: StatsCard(
                  title: 'Active Users',
                  value: '1,208',
                  subtitle: 'Last 24 hours',
                  icon: Icons.trending_up_rounded,
                  colors: [
                    Colors.teal.shade400,
                    Colors.teal.shade600,
                    Colors.teal.shade800,
                  ],
                  onTap: () {},
                ),
              ),
              const SizedBox(height: 16),

              HalfCenter(
                child: CustomTextField(
                  label: 'Your Name',
                  hintText: 'Type here…',
                  icon: Icons.person_outline_rounded,
                  controller: _controller,
                ),
              ),
              const SizedBox(height: 16),

              HalfCenter(
                child: ModernButton(
                  text: 'Continue',
                  icon: Icons.arrow_forward_rounded,
                  height: 40,
                  onPressed: () {},
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// ---- Gradient Helpers ----
List<double> _normalizedStops(int colorCount, [List<double>? stops]) {
  if (colorCount <= 1) return const [0.0];
  if (stops != null && stops.length == colorCount) return stops;
  return List<double>.generate(colorCount, (i) => i / (colorCount - 1));
}

LinearGradient _safeLinearGradient({
  required List<Color> colors,
  List<double>? stops,
  AlignmentGeometry begin = Alignment.topLeft,
  AlignmentGeometry end = Alignment.bottomRight,
}) {
  final _stops = _normalizedStops(colors.length, stops);
  return LinearGradient(colors: colors, stops: _stops, begin: begin, end: end);
}

/// =================== GradientCard (no animation) ===================
class GradientCard extends StatelessWidget {
  final Widget child;
  final List<Color>? colors;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final double? elevation;
  final VoidCallback? onTap;

  const GradientCard({
    super.key,
    required this.child,
    this.colors,
    this.padding,
    this.borderRadius,
    this.elevation,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final defaultColors = [
      Colors.teal.shade200.withOpacity(0.9),
      Colors.teal.shade400.withOpacity(0.95),
      Colors.teal.shade600,
      Colors.teal.shade800,
    ];
    final effectiveColors = colors ?? defaultColors;

    return InkWell(
      borderRadius: BorderRadius.circular(borderRadius ?? 28),
      onTap: onTap,
      child: Container(
        padding: padding ?? const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: _safeLinearGradient(colors: effectiveColors),
          borderRadius: BorderRadius.circular(borderRadius ?? 28),
          boxShadow: [
            BoxShadow(
              color: effectiveColors.first.withOpacity(0.4),
              blurRadius: elevation ?? 20,
              offset: const Offset(0, 12),
              spreadRadius: 2,
            ),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular((borderRadius ?? 28) - 2),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 1, sigmaY: 1),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// =================== CustomTextField (no animation) ===================
class CustomTextField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final IconData? icon;
  final bool obscureText;
  final String? hintText;
  final int? maxLines;

  const CustomTextField({
    super.key,
    required this.label,
    required this.controller,
    this.keyboardType,
    this.validator,
    this.icon,
    this.obscureText = false,
    this.hintText,
    this.maxLines = 1,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: _safeLinearGradient(
            colors: [Colors.white, Colors.grey.shade50],
          ),
          boxShadow: [
            BoxShadow(
              color: _isFocused
                  ? Colors.teal.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.1),
              blurRadius: _isFocused ? 20 : 12,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: _isFocused ? Colors.teal.shade300 : Colors.transparent,
            width: 2,
          ),
        ),
        child: TextFormField(
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          validator: widget.validator,
          obscureText: widget.obscureText,
          maxLines: widget.maxLines,
          onTap: () => setState(() => _isFocused = true),
          onTapOutside: (_) => setState(() => _isFocused = false),
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hintText,
            prefixIcon: widget.icon != null
                ? Icon(widget.icon, color: Colors.teal.shade700, size: 20)
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.transparent,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 20,
            ),
          ),
        ),
      ),
    );
  }
}

/// =================== StatsCard (no animation) ===================
class StatsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback? onTap;
  final String? subtitle;

  const StatsCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.colors,
    this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final gradientColors = [
      ...colors,
      if (colors.isNotEmpty) colors.last.withOpacity(0.85),
    ];

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: _safeLinearGradient(colors: gradientColors),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: colors.first.withOpacity(0.4),
              blurRadius: 25,
              offset: const Offset(0, 12),
            ),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: Colors.white),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// =================== ModernButton (no animation) ===================
class ModernButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final List<Color>? colors;
  final IconData? icon;
  final double? width;
  final double? height;

  const ModernButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.colors,
    this.icon,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final defaultColors = [
      Colors.teal.shade400,
      Colors.teal.shade600,
      Colors.teal.shade800,
    ];
    final gradientColors = colors ?? defaultColors;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onPressed,
      child: Container(
        width: width,
        height: height ?? 60,
        decoration: BoxDecoration(
          gradient: _safeLinearGradient(colors: gradientColors),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradientColors.first.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(width: 12),
            ],
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/customer.dart';
import '../services/firebase_service.dart';
import '../widgets/ui_components.dart';

class AddCustomerScreen extends StatefulWidget {
  const AddCustomerScreen({super.key});

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _idCardController = TextEditingController();
  final _phoneController = TextEditingController();

  /// Read-only display of computed total (kept numeric for storage)
  final _amountController = TextEditingController();

  // ===== Global discount controls (admin only) =====
  bool _discountEnabled = false;
  final _discountController = TextEditingController(text: '0'); // percentage

  bool _isLoading = false;

  // ===== Admin lock (password) =====
  static const String _adminPassword = 'mirabella2303'; // <-- change me
  bool _adminUnlocked = false;

  // ===== Local persistence key =====
  static const String _kCatalogKey = 'service_catalog_v1';

  // Rupee helper for UI row tags (ASCII "Rs" to avoid PDF font issues)
  String _formatRs(num v) =>
      'Rs ${NumberFormat.decimalPattern('en_IN').format(v)}';

  // ---- Categories ----
  static const List<String> _categories = <String>[
    'Ladies Salon',
    'Men Salon',
    'Indoor Swimming Pool',
    'Gym',
  ];

  /// Default catalog (used on first run or when reset)
  static const Map<String, Map<String, num>> _defaultServicePrices = {
    'Ladies Salon': {
      'Simple Fical': 1500,
      'Deep Cleansing': 1000,
      'Hydra Hands': 3900,
      'Kashees Whitening': 4900,
      'Whitening': 2500,
      'Simple Cleansing': 800,
      'Skin Polish': 2000,
      'Gold Facial': 3200,
      'Jensen': 5000,
      'Layer Cut': 2500,
      'Step Cutting': 3000,
      'V Cut': 1000,
      'U Cut': 1000,
      'Baby Cut': 1000,
      'Boy Cut': 1200,
      'Feather Cut': 3200,
      'Bob Cut': 1500,
      'Butterfly Cut': 2200,
      'Hair Triming': 1000,
      'Rough Triming': 1500,
      'Meni / Pedi': 3000,
      'Face Wax': 1000,
      'Full Body Wax': 5000,
      'Army Wax (Half)': 500,
      'Army Wax (Full)': 1000,
      'Leg Wax (Half)': 600,
      'Leg Wax (Full)': 1500,
      'Hair Rebounding': 00,
      'Shoulder Length (1 Shade)': 6000,
      'Shoulder Length (With CutDown)': 10000,
      'Sticking (Highligths)': 10000,
      'Sticking (Low Light)': 10000,
      'Sticking (Cap Sticking)': 5000,
      'Bikini Wax': 1200,
      'Smokey': 7000,
      'Model': 3500,
      'Soft': 3000,
      'Bridal': 25000,
      'Party': 5000,
      'Nikkah Bridal': 15000,
      'Mangni Bridal': 10000,
      'Full Body (Massage)': 7000,
      'Shoulder (Massage)': 1000,
      'Feet (Massage)': 1000,
      'Arms (Massage)': 1000,
      'Back (Massage)': 1000,
      'Head (Massage)': 1000,
    },
    'Men Salon': {
      'Haircut': 300,
      'Hair Cut w/Blow Dry': 500,
      'Shave Foam': 150,
      'Shave Simple': 150,
      'Baby Cutting': 200,
      'Hair Styling': 200,
      'Hair Color Apply': 200,
      'Threading': 100,
      'Eye Brow Threading': 100,
      'Normal Facial': 1000,
      'Facial Skin Polish': 2000,
      'Face Massage': 200,
    },
    'Indoor Swimming Pool': {
      'Kids (Non Memebers)': 500,
      'Kids (Memebers)': 500,
      'Adults (Non Memebers)': 1000,
      'Adults (Memebers)': 500,
    },
    'Gym': {'Day Pass': 200, 'Weekly Pass': 1000, 'Monthly Membership': 3000},
  };

  /// Mutable, persisted catalog
  static Map<String, Map<String, num>> _servicePrices = _defaultServicePrices
      .map((k, v) => MapEntry(k, Map<String, num>.from(v)));

  String? _selectedCategory;
  final Set<String> _selectedServices = <String>{};
  double _computedTotal = 0.0;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _idCardController.dispose();
    _phoneController.dispose();
    _amountController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  // ===== Persistence =====

  Future<void> _loadCatalog() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_kCatalogKey);
    if (jsonStr == null) return; // use defaults
    try {
      final Map<String, dynamic> raw = json.decode(jsonStr);
      final Map<String, Map<String, num>> parsed = raw.map((cat, inner) {
        final innerMap = Map<String, dynamic>.from(inner);
        final converted = innerMap.map(
          (svc, price) => MapEntry(svc, (price as num)),
        );
        return MapEntry(cat, converted);
      });
      setState(() {
        _servicePrices = parsed;
      });
    } catch (_) {
      setState(() {
        _servicePrices = _defaultServicePrices.map(
          (k, v) => MapEntry(k, Map<String, num>.from(v)),
        );
      });
    }
  }

  Future<void> _saveCatalog() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = json.encode(_servicePrices);
    await prefs.setString(_kCatalogKey, jsonStr);
  }

  Future<void> _resetCatalogToDefaults() async {
    setState(() {
      _servicePrices = _defaultServicePrices.map(
        (k, v) => MapEntry(k, Map<String, num>.from(v)),
      );
      _selectedServices.clear();
      _updateTotal();
    });
    await _saveCatalog();
    _toast('Catalog reset to defaults');
  }

  // ===== UI helpers =====

  void _updateTotal() {
    final prices = _servicePrices[_selectedCategory] ?? const {};
    double subtotal = 0;
    for (final s in _selectedServices) {
      subtotal += (prices[s] ?? 0).toDouble();
    }

    double pct = 0;
    if (_discountEnabled) {
      pct = double.tryParse(_discountController.text.replaceAll(',', '.')) ?? 0;
      if (pct.isNaN || pct.isInfinite) pct = 0;
      pct = pct.clamp(0, 100);
    }

    final discounted = subtotal * (1 - pct / 100);
    _computedTotal = discounted;
    _amountController.text = discounted.toStringAsFixed(0);
    setState(() {});
  }

  Future<void> _promptUnlock() async {
    final passCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Admin Access'),
        content: TextField(
          controller: passCtrl,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Enter password',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
    if (ok == true) {
      if (passCtrl.text == _adminPassword) {
        setState(() => _adminUnlocked = true);
        _toast('Admin unlocked');
      } else {
        _showError('Wrong password');
      }
    }
  }

  void _lockAdmin() {
    setState(() => _adminUnlocked = false);
    _toast('Admin locked');
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openCatalogEditor() {
    if (!_adminUnlocked) {
      _showError('Unlock admin to edit services & prices.');
      return;
    }
    if (_selectedCategory == null) {
      _showError('Please select a category first.');
      return;
    }

    final cat = _selectedCategory!;
    final current = Map<String, num>.from(_servicePrices[cat] ?? {});

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) {
        final entries = current.entries.toList();
        final names = entries.map((e) => e.key).toList();
        final prices = entries.map((e) => e.value.toString()).toList();

        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final insets = MediaQuery.of(ctx).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 16 + insets,
              ),
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.75,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Edit: $cat',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _resetCatalogToDefaults,
                          icon: const Icon(Icons.restart_alt_rounded),
                          label: const Text('Reset defaults'),
                        ),
                        IconButton(
                          tooltip: 'Add service',
                          onPressed: () {
                            setSheet(() {
                              names.add('');
                              prices.add('0');
                            });
                          },
                          icon: const Icon(Icons.add),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: names.length,
                        itemBuilder: (c, i) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: LayoutBuilder(
                              builder: (c, cons) {
                                final narrow = cons.maxWidth < 560;
                                final nameField = TextFormField(
                                  initialValue: names[i],
                                  onChanged: (v) => names[i] = v,
                                  decoration: const InputDecoration(
                                    labelText: 'Service name',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                );
                                final priceField = TextFormField(
                                  initialValue: prices[i],
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: false,
                                      ),
                                  onChanged: (v) => prices[i] = v,
                                  decoration: const InputDecoration(
                                    labelText: 'Price (Rs)',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                );

                                if (narrow) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      nameField,
                                      const SizedBox(height: 8),
                                      priceField,
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: IconButton(
                                          tooltip: 'Delete',
                                          onPressed: () {
                                            setSheet(() {
                                              names.removeAt(i);
                                              prices.removeAt(i);
                                            });
                                          },
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    Expanded(flex: 6, child: nameField),
                                    const SizedBox(width: 8),
                                    Expanded(flex: 3, child: priceField),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      tooltip: 'Delete',
                                      onPressed: () {
                                        setSheet(() {
                                          names.removeAt(i);
                                          prices.removeAt(i);
                                        });
                                      },
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.save),
                        label: const Text('Save changes'),
                        onPressed: () async {
                          final Map<String, num> newMap = {};
                          for (var i = 0; i < names.length; i++) {
                            final name = names[i].trim();
                            if (name.isEmpty) continue;
                            final price =
                                num.tryParse(prices[i].replaceAll(',', '')) ??
                                0;
                            newMap[name] = price;
                          }
                          setState(() {
                            _servicePrices[cat] = newMap;
                            _selectedServices.removeWhere(
                              (s) => !newMap.keys.contains(s),
                            );
                            _updateTotal();
                          });
                          await _saveCatalog();
                          if (mounted) Navigator.pop(ctx);
                          _toast('Catalog updated');
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pricesForCategory = _selectedCategory == null
        ? const <String, num>{}
        : (_servicePrices[_selectedCategory!] ?? {});

    final List<String> serviceOptions = pricesForCategory.keys.toList();

    final double _currentPct = (() {
      final v = double.tryParse(_discountController.text.replaceAll(',', '.'));
      if (v == null || v.isNaN || v.isInfinite) return 0.0;
      return v.clamp(0, 100).toDouble();
    })();

    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,

      // ---------- NEW: Beautiful Branded Top Bar ----------
      appBar: _RahizAppBar(
        businessName: 'Rahiz Spa and Salon',
        pageTitle: 'Add New Customer',
        adminUnlocked: _adminUnlocked,
        onLockToggle: _adminUnlocked ? _lockAdmin : _promptUnlock,
      ),

      // -----------------------------------------------------
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(0, 20, 0, 20 + viewInsets * 0.4),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Header (responsive centered)
                  _ResponsiveCenter(
                    child: GradientCard(
                      colors: [
                        Colors.indigo.shade300,
                        Colors.indigo.shade500,
                        Colors.indigo.shade700,
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
                              Icons.person_add_rounded,
                              size: 48,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Customer Information',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Please fill in all customer details',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Form container (responsive centered)
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
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            CustomTextField(
                              label: 'Customer Name',
                              controller: _nameController,
                              icon: Icons.person_rounded,
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Please enter name'
                                  : null,
                            ),
                            CustomTextField(
                              label: 'Address (optional)',
                              controller: _addressController,
                              icon: Icons.location_on_rounded,
                              validator: (_) => null,
                            ),
                            CustomTextField(
                              label: 'ID Card Number (optional)',
                              controller: _idCardController,
                              icon: Icons.credit_card_rounded,
                              validator: (_) => null,
                            ),
                            CustomTextField(
                              label: 'Phone Number',
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              icon: Icons.phone_rounded,
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Please enter phone number'
                                  : null,
                            ),

                            // -------- Category Dropdown --------
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.1),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      value: _selectedCategory,
                                      decoration: InputDecoration(
                                        labelText: 'Select Category',
                                        labelStyle: TextStyle(
                                          color: Colors.teal.shade600,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        prefixIcon: Container(
                                          margin: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.teal.shade50,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.category_rounded,
                                            color: Colors.teal.shade600,
                                            size: 20,
                                          ),
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey.shade200,
                                            width: 1,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.teal.shade400,
                                            width: 2,
                                          ),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.red.shade300,
                                            width: 1,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 16,
                                            ),
                                      ),
                                      items: _categories
                                          .map(
                                            (c) => DropdownMenuItem(
                                              value: c,
                                              child: Text(
                                                c,
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) {
                                        setState(() {
                                          _selectedCategory = v;
                                          _selectedServices.clear();
                                          _updateTotal();
                                        });
                                      },
                                      validator: (v) => v == null
                                          ? 'Please select a category'
                                          : null,
                                    ),

                                    if (_adminUnlocked &&
                                        _selectedCategory != null)
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton.icon(
                                          onPressed: _openCatalogEditor,
                                          icon: const Icon(
                                            Icons.edit_note_rounded,
                                          ),
                                          label: const Text(
                                            'Manage services & prices',
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),

                            // ===== Admin Discount Panel =====
                            if (_adminUnlocked)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      8,
                                      12,
                                      8,
                                    ),
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        final narrow =
                                            constraints.maxWidth < 520;
                                        final percentField = SizedBox(
                                          width: narrow ? double.infinity : 140,
                                          child: TextFormField(
                                            enabled: _discountEnabled,
                                            controller: _discountController,
                                            keyboardType:
                                                const TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                            onChanged: (_) => _updateTotal(),
                                            decoration: InputDecoration(
                                              labelText: 'Discount %',
                                              hintText: 'e.g. 10',
                                              suffixText: '%',
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              isDense: true,
                                            ),
                                          ),
                                        );

                                        final switchTile = SwitchListTile(
                                          value: _discountEnabled,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 4,
                                              ),
                                          onChanged: (val) {
                                            setState(() {
                                              _discountEnabled = val;
                                            });
                                            _updateTotal();
                                          },
                                          title: const Text(
                                            'Apply global discount',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          subtitle: Text(
                                            _discountEnabled
                                                ? 'Active (${_currentPct.toStringAsFixed(0)}%)'
                                                : 'Disabled',
                                          ),
                                        );

                                        if (narrow) {
                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              switchTile,
                                              const SizedBox(height: 8),
                                              percentField,
                                            ],
                                          );
                                        }
                                        return Row(
                                          children: [
                                            Expanded(child: switchTile),
                                            const SizedBox(width: 12),
                                            percentField,
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),

                            // -------- Services: MULTI-SELECT CHECKBOXES (SCROLLABLE) --------
                            if (_selectedCategory != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    color: Colors.grey.shade50,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.08),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 6,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.fromLTRB(
                                            16,
                                            8,
                                            16,
                                            4,
                                          ),
                                          child: Text(
                                            'Select Services',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),

                                        // Responsive list height
                                        LayoutBuilder(
                                          builder: (ctx, cons) {
                                            final h = MediaQuery.of(
                                              ctx,
                                            ).size.height;
                                            final base = h * 0.38;
                                            final listH = base
                                                .clamp(220.0, 420.0)
                                                .toDouble();
                                            return SizedBox(
                                              height: listH,
                                              child: ListView.separated(
                                                keyboardDismissBehavior:
                                                    ScrollViewKeyboardDismissBehavior
                                                        .onDrag,
                                                itemCount:
                                                    serviceOptions.length,
                                                separatorBuilder: (_, __) =>
                                                    Divider(
                                                      height: 1,
                                                      thickness: 0.5,
                                                      color:
                                                          Colors.grey.shade200,
                                                    ),
                                                itemBuilder: (context, index) {
                                                  final s =
                                                      serviceOptions[index];
                                                  final selected =
                                                      _selectedServices
                                                          .contains(s);
                                                  final price =
                                                      (pricesForCategory[s] ??
                                                              0)
                                                          .toDouble();

                                                  return CheckboxListTile(
                                                    value: selected,
                                                    onChanged: (checked) {
                                                      setState(() {
                                                        if (checked == true) {
                                                          _selectedServices.add(
                                                            s,
                                                          );
                                                        } else {
                                                          _selectedServices
                                                              .remove(s);
                                                        }
                                                        _updateTotal();
                                                      });
                                                    },
                                                    dense: true,
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    contentPadding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                        ),
                                                    controlAffinity:
                                                        ListTileControlAffinity
                                                            .leading,
                                                    title: Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            s,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 16,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                ),
                                                          ),
                                                        ),
                                                        FittedBox(
                                                          fit: BoxFit.scaleDown,
                                                          child: Text(
                                                            _formatRs(price),
                                                            style: TextStyle(
                                                              color: Colors
                                                                  .grey
                                                                  .shade700,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                            );
                                          },
                                        ),

                                        if (_selectedServices.isEmpty)
                                          const Padding(
                                            padding: EdgeInsets.fromLTRB(
                                              16,
                                              0,
                                              16,
                                              8,
                                            ),
                                            child: Text(
                                              'Please select at least one service',
                                              style: TextStyle(
                                                color: Colors.redAccent,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                            // -------- Total Amount (Read-only, Rs) --------
                            Padding(
                              padding: const EdgeInsets.only(top: 6, bottom: 6),
                              child: TextFormField(
                                controller: _amountController,
                                readOnly: true,
                                enabled: false,
                                decoration: InputDecoration(
                                  labelText: _discountEnabled && _currentPct > 0
                                      ? 'Total (after ${_currentPct.toStringAsFixed(0)}% discount)'
                                      : 'Total (Rs.)',
                                  prefixIcon: Container(
                                    margin: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.teal.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.currency_rupee_rounded,
                                      color: Colors.teal.shade600,
                                      size: 20,
                                    ),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade100,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Submit button (mobile-safe hit size)
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _submitForm,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal.shade600,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isLoading
                                    ? Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: const [
                                          SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    Colors.white,
                                                  ),
                                            ),
                                          ),
                                          SizedBox(width: 10),
                                          Text(
                                            'Adding Customer...',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: const [
                                          Icon(Icons.add_rounded, size: 20),
                                          SizedBox(width: 10),
                                          Flexible(
                                            child: Text(
                                              'Add Customer',
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      _showError('Please select a category.');
      return;
    }
    if (_selectedServices.isEmpty) {
      _showError('Please select at least one service.');
      return;
    }

    setState(() => _isLoading = true);

    final address = _addressController.text.trim();
    final idCard = _idCardController.text.trim();
    final joinedServices = _selectedServices.join(', ');

    final customer = Customer(
      id: '',
      name: _nameController.text.trim(),
      address: address,
      idCard: idCard,
      phone: _phoneController.text.trim(),
      category: _selectedCategory!,
      service: joinedServices,
      amount: double.tryParse(_amountController.text) ?? _computedTotal,
      date: DateTime.now(),
    );

    try {
      await FirebaseService.addCustomer(customer);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 12),
                Text(
                  'Customer added successfully!',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
      _clearForm();
    } catch (e) {
      if (mounted) {
        _showError('Error adding customer: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    _nameController.clear();
    _addressController.clear();
    _idCardController.clear();
    _phoneController.clear();
    _amountController.clear();
    setState(() {
      _selectedCategory = null;
      _selectedServices.clear();
      _computedTotal = 0.0;
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
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

// ===================== NEW: Custom Branded App Bar =====================
class _RahizAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String businessName;
  final String pageTitle;
  final bool adminUnlocked;
  final VoidCallback onLockToggle;

  const _RahizAppBar({
    Key? key,
    required this.businessName,
    required this.pageTitle,
    required this.adminUnlocked,
    required this.onLockToggle,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(98);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = DateFormat('EEE, d MMM y').format(now);

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
                // Round monogram (acts like a subtle logo)
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
                      // Business name (prominent)
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
                      // Page title + date chip row
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

                // Admin lock/unlock action
                const SizedBox(width: 8),
                Tooltip(
                  message: adminUnlocked ? 'Lock admin' : 'Unlock admin',
                  waitDuration: const Duration(milliseconds: 400),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onLockToggle,
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
                        child: Row(
                          children: [
                            Icon(
                              adminUnlocked
                                  ? Icons.lock_open_rounded
                                  : Icons.lock_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              adminUnlocked ? 'Admin' : 'Locked',
                              style: const TextStyle(
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

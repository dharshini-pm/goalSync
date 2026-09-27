import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../auth/services/auth_service.dart';
import '../../models/transaction_model.dart';
import '../../services/transaction_service.dart';
import '../widgets/transaction_card.dart';
import 'transaction_detail_page.dart';

/// Dedicated Transactions page with summary metrics, filter tabs,
/// transaction cards, and an empty state.
class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  String _selectedFilter = 'All'; // 'All', 'Debit', 'Credit'

  @override
  void initState() {
    super.initState();
    TransactionService.instance.init();
    TransactionService.instance.addListener(_onServiceUpdate);
    final userId = AuthService.instance.currentUser?.id;
    if (userId != null && userId.isNotEmpty) {
      TransactionService.instance.fetchTransactionsFromBackend(userId);
    }
  }

  @override
  void dispose() {
    TransactionService.instance.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  void _openAddTransactionModal(String userId) {
    showModalBottomSheet<TransactionModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddEditTransactionModal(userId: userId),
    );
  }

  String _fmt(double v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(2)}Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(2)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}K';
    return '₹${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userId = AuthService.instance.currentUser?.id ?? '';
    final allTransactions =
        TransactionService.instance.getTransactionsForUser(userId);

    final totalCount = allTransactions.length;
    final totalDebit = TransactionService.instance.getTotalDebit(userId);
    final totalCredit = TransactionService.instance.getTotalCredit(userId);

    final filteredTransactions = allTransactions.where((t) {
      if (_selectedFilter == 'Debit') return t.isDebit;
      if (_selectedFilter == 'Credit') return t.isCredit;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text(
          'Transactions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        foregroundColor: isDark
            ? AppColors.textPrimaryDark
            : AppColors.textPrimaryLight,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Add Transaction',
            icon: const Icon(Icons.add_rounded, size: 24),
            onPressed: () => _openAddTransactionModal(userId),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddTransactionModal(userId),
        backgroundColor: AppColors.electricCyan,
        foregroundColor: AppColors.deepNavy,
        tooltip: 'Add Transaction',
        child: const Icon(Icons.add_rounded),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.pagePaddingH,
            vertical: AppDimensions.space16,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Overview Summary Bar
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.space16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurface
                          : AppColors.lightSurface,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusLg),
                      border: Border.all(
                        color: isDark
                            ? AppColors.navyBorder
                            : const Color(0xFFD6E4F0),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withAlpha(25)
                              : Colors.black.withAlpha(6),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _SummaryMetric(
                            label: 'Total Count',
                            value: '$totalCount',
                            color: AppColors.electricCyan,
                            isDark: isDark,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 36,
                          color: isDark
                              ? AppColors.navyBorder
                              : const Color(0xFFE2ECF5),
                        ),
                        Expanded(
                          child: _SummaryMetric(
                            label: 'Total Outflow',
                            value: _fmt(totalDebit),
                            color: AppColors.error,
                            isDark: isDark,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 36,
                          color: isDark
                              ? AppColors.navyBorder
                              : const Color(0xFFE2ECF5),
                        ),
                        Expanded(
                          child: _SummaryMetric(
                            label: 'Total Inflow',
                            value: _fmt(totalCredit),
                            color: AppColors.mint,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space16),

                  // Filter Row
                  if (allTransactions.isNotEmpty) ...[
                    Row(
                      children: [
                        Text(
                          'RECENT TRANSACTIONS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                        const Spacer(),
                        _filterChip('All', isDark),
                        const SizedBox(width: 6),
                        _filterChip('Debit', isDark),
                        const SizedBox(width: 6),
                        _filterChip('Credit', isDark),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.space12),
                  ],

                  // Content: Empty State OR Transaction List
                  if (allTransactions.isEmpty)
                    _buildEmptyState(context, isDark, userId)
                  else if (filteredTransactions.isEmpty)
                    _buildNoFilterResults(isDark)
                  else
                    ...filteredTransactions.map(
                      (tx) => TransactionCard(
                        transaction: tx,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  TransactionDetailPage(transaction: tx),
                            ),
                          );
                          if (mounted) setState(() {});
                        },
                      ),
                    ),
                  const SizedBox(height: 80), // Padding for FAB
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String title, bool isDark) {
    final isSelected = _selectedFilter == title;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = title),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.electricCyan
              : (isDark
                  ? AppColors.darkSurfaceVariant
                  : AppColors.lightSurfaceVariant),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.electricCyan
                : (isDark ? AppColors.navyBorder : const Color(0xFFD6E4F0)),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isSelected
                ? AppColors.deepNavy
                : (isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
      BuildContext context, bool isDark, String userId) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space24,
        vertical: AppDimensions.space32,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(
          color: isDark ? AppColors.navyBorder : const Color(0xFFD6E4F0),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isDark ? AppColors.navyMid : const Color(0xFFE8F3FA),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              size: 32,
              color: isDark ? AppColors.electricCyan : const Color(0xFF0096B4),
            ),
          ),
          const SizedBox(height: AppDimensions.space16),
          Text(
            'No transactions yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: AppDimensions.space8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Text(
              'Transactions will appear when financial data is connected.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 1.4,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.space20),
          ElevatedButton.icon(
            onPressed: () => _openAddTransactionModal(userId),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Add Transaction'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.electricCyan,
              foregroundColor: AppColors.deepNavy,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoFilterResults(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Center(
        child: Text(
          'No $_selectedFilter transactions found.',
          style: TextStyle(
            fontSize: 13,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isDark
                ? AppColors.textTertiaryDark
                : AppColors.textTertiaryLight,
          ),
        ),
      ],
    );
  }
}

/// Modal bottom sheet for adding or editing a transaction.
class AddEditTransactionModal extends StatefulWidget {
  final String userId;
  final TransactionModel? initialTransaction;

  const AddEditTransactionModal({
    super.key,
    required this.userId,
    this.initialTransaction,
  });

  @override
  State<AddEditTransactionModal> createState() =>
      _AddEditTransactionModalState();
}

class _AddEditTransactionModalState extends State<AddEditTransactionModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _merchantController;
  late TextEditingController _notesController;

  late TransactionType _type;
  late PaymentMethod _paymentMethod;
  late String _category;
  late DateTime _selectedDate;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final init = widget.initialTransaction;
    _amountController = TextEditingController(
      text: init != null
          ? (init.amount.truncateToDouble() == init.amount
              ? init.amount.toStringAsFixed(0)
              : init.amount.toStringAsFixed(2))
          : '',
    );
    _merchantController =
        TextEditingController(text: init?.merchantName ?? '');
    _notesController = TextEditingController(text: init?.notes ?? '');
    _type = init?.type ?? TransactionType.debit;
    _paymentMethod = init?.paymentMethod ?? PaymentMethod.upi;
    _category = init?.category ?? TransactionCategories.foodAndDining;
    _selectedDate = init?.dateTime ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final isEdit = widget.initialTransaction != null;
    final TransactionResult result;

    if (isEdit) {
      result = await TransactionService.instance.updateTransaction(
        userId: widget.userId,
        id: widget.initialTransaction!.id,
        amountRaw: _amountController.text,
        type: _type,
        merchantName: _merchantController.text,
        category: _category,
        paymentMethod: _paymentMethod,
        dateTime: _selectedDate,
        notes: _notesController.text,
      );
    } else {
      result = await TransactionService.instance.createTransaction(
        userId: widget.userId,
        amountRaw: _amountController.text,
        type: _type,
        merchantName: _merchantController.text,
        category: _category,
        paymentMethod: _paymentMethod,
        dateTime: _selectedDate,
        notes: _notesController.text,
      );
    }

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (result.isSuccess) {
      Navigator.of(context).pop(result.transaction);
    } else {
      setState(() {
        _errorMessage = result.errorMessage ?? 'An error occurred.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEdit = widget.initialTransaction != null;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: AppDimensions.space20,
        left: AppDimensions.pagePaddingH,
        right: AppDimensions.pagePaddingH,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Text(
                    isEdit ? 'Edit Transaction' : 'Add Transaction',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.space12),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error.withAlpha(60)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.space12),
              ],

              // Type Selector: Debit / Credit
              Row(
                children: [
                  Expanded(
                    child: _typeButton(
                      title: 'Debit (Outflow)',
                      type: TransactionType.debit,
                      activeColor: AppColors.error,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.space10),
                  Expanded(
                    child: _typeButton(
                      title: 'Credit (Inflow)',
                      type: TransactionType.credit,
                      activeColor: AppColors.mint,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.space16),

              // Amount Field
              TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount (₹)',
                  prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                ),
                validator: (val) {
                  final parsed = double.tryParse(val?.trim() ?? '');
                  if (parsed == null || parsed <= 0) {
                    return 'Enter a valid amount greater than 0.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppDimensions.space12),

              // Merchant Field
              TextFormField(
                controller: _merchantController,
                decoration: InputDecoration(
                  labelText: 'Merchant Name',
                  prefixIcon: const Icon(Icons.storefront_outlined, size: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Merchant name is required.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppDimensions.space12),

              // Category Dropdown
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: InputDecoration(
                  labelText: 'Category',
                  prefixIcon: const Icon(Icons.category_outlined, size: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                ),
                items: TransactionCategories.all.map((cat) {
                  return DropdownMenuItem(
                    value: cat,
                    child: Text(cat),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _category = val);
                },
              ),
              const SizedBox(height: AppDimensions.space12),

              // Payment Method Dropdown
              DropdownButtonFormField<PaymentMethod>(
                initialValue: _paymentMethod,
                decoration: InputDecoration(
                  labelText: 'Payment Method',
                  prefixIcon: const Icon(Icons.payment_outlined, size: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                ),
                items: PaymentMethod.values.map((method) {
                  return DropdownMenuItem(
                    value: method,
                    child: Text(method.displayName),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _paymentMethod = val);
                },
              ),
              const SizedBox(height: AppDimensions.space12),

              // Notes Field
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Notes (Optional)',
                  prefixIcon: const Icon(Icons.notes_outlined, size: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.space20),

              // Submit Button
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.electricCyan,
                  foregroundColor: AppColors.deepNavy,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(AppColors.deepNavy),
                        ),
                      )
                    : Text(isEdit ? 'Save Changes' : 'Add Transaction'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeButton({
    required String title,
    required TransactionType type,
    required Color activeColor,
    required bool isDark,
  }) {
    final isSelected = _type == type;
    return InkWell(
      onTap: () => setState(() => _type = type),
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withAlpha(35)
              : (isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(
            color: isSelected
                ? activeColor
                : (isDark ? AppColors.navyBorder : const Color(0xFFD6E4F0)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected
                ? activeColor
                : (isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight),
          ),
        ),
      ),
    );
  }
}

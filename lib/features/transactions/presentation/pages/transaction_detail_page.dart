import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../models/transaction_model.dart';
import '../../services/transaction_service.dart';
import 'transactions_page.dart';

/// Dedicated transaction details view showing all fields and edit/delete actions.
class TransactionDetailPage extends StatefulWidget {
  final TransactionModel transaction;

  const TransactionDetailPage({
    super.key,
    required this.transaction,
  });

  @override
  State<TransactionDetailPage> createState() => _TransactionDetailPageState();
}

class _TransactionDetailPageState extends State<TransactionDetailPage> {
  late TransactionModel _transaction;

  @override
  void initState() {
    super.initState();
    _transaction = widget.transaction;
  }

  void _onEditTapped() async {
    final updated = await showModalBottomSheet<TransactionModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddEditTransactionModal(
        initialTransaction: _transaction,
        userId: _transaction.userId,
      ),
    );

    if (updated != null && mounted) {
      setState(() {
        _transaction = updated;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction updated successfully.'),
          backgroundColor: AppColors.mint,
        ),
      );
    }
  }

  void _onDeleteTapped() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: Text(
          'Are you sure you want to delete this ${_transaction.formattedAmount} transaction at ${_transaction.merchantName}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await TransactionService.instance.deleteTransaction(
        _transaction.userId,
        _transaction.id,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDebit = _transaction.isDebit;
    final badgeColor = isDebit ? AppColors.error : AppColors.mint;
    final badgeBg = isDebit
        ? AppColors.error.withAlpha(25)
        : AppColors.mint.withAlpha(25);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text(
          'Transaction Details',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        foregroundColor: isDark
            ? AppColors.textPrimaryDark
            : AppColors.textPrimaryLight,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Edit Transaction',
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: _onEditTapped,
          ),
          IconButton(
            tooltip: 'Delete Transaction',
            icon: const Icon(Icons.delete_outline_rounded,
                size: 20, color: AppColors.error),
            onPressed: _onDeleteTapped,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.pagePaddingH,
            vertical: AppDimensions.space20,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Amount hero card
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.space24),
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
                              ? Colors.black.withAlpha(30)
                              : Colors.black.withAlpha(8),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: badgeColor.withAlpha(80)),
                          ),
                          child: Text(
                            _transaction.type.displayName.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: badgeColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.space12),
                        Text(
                          _transaction.signedFormattedAmount,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.0,
                            color: badgeColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _transaction.merchantName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _transaction.formattedDateTime,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppColors.textTertiaryDark
                                : AppColors.textTertiaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space20),

                  // Detail rows container
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.space20),
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
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TRANSACTION DETAILS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.space16),
                        _DetailRow(
                          icon: Icons.storefront_outlined,
                          label: 'Merchant',
                          value: _transaction.merchantName,
                          isDark: isDark,
                        ),
                        const Divider(height: 24),
                        _DetailRow(
                          icon: Icons.category_outlined,
                          label: 'Category',
                          value: _transaction.category,
                          isDark: isDark,
                        ),
                        const Divider(height: 24),
                        _DetailRow(
                          icon: Icons.payment_outlined,
                          label: 'Payment Method',
                          value: _transaction.paymentMethod.displayName,
                          isDark: isDark,
                        ),
                        const Divider(height: 24),
                        _DetailRow(
                          icon: Icons.calendar_today_outlined,
                          label: 'Date & Time',
                          value: _transaction.formattedDateTime,
                          isDark: isDark,
                        ),
                        const Divider(height: 24),
                        _DetailRow(
                          icon: Icons.notes_outlined,
                          label: 'Notes',
                          value: _transaction.notes?.isNotEmpty == true
                              ? _transaction.notes!
                              : 'No notes provided',
                          isDark: isDark,
                          isDimmed: _transaction.notes?.isNotEmpty != true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space24),

                  // Edit button
                  ElevatedButton.icon(
                    onPressed: _onEditTapped,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit Transaction'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.electricCyan,
                      foregroundColor: AppColors.deepNavy,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMd),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
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
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  final bool isDimmed;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
    this.isDimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: isDark
              ? AppColors.textTertiaryDark
              : AppColors.textTertiaryLight,
        ),
        const SizedBox(width: AppDimensions.space12),
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isDimmed ? FontWeight.w400 : FontWeight.w700,
              color: isDimmed
                  ? (isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight)
                  : (isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight),
            ),
          ),
        ),
      ],
    );
  }
}

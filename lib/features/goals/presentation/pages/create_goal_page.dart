import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../auth/services/auth_service.dart';
import '../../models/goal_model.dart';
import '../../services/goal_service.dart';

/// Screen for creating a new financial goal.
class CreateGoalPage extends StatefulWidget {
  final GoalModel? existingGoal;

  const CreateGoalPage({super.key, this.existingGoal});

  @override
  State<CreateGoalPage> createState() => _CreateGoalPageState();
}

class _CreateGoalPageState extends State<CreateGoalPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  final _currentController = TextEditingController();

  GoalCategory _category = GoalCategory.personal;
  GoalPriority _priority = GoalPriority.important;
  DateTime? _targetDate;
  bool _isLoading = false;

  bool get _isEditing => widget.existingGoal != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final g = widget.existingGoal!;
      _nameController.text = g.name;
      _targetController.text = g.targetAmount.toStringAsFixed(2);
      _currentController.text = g.currentAmount.toStringAsFixed(2);
      _category = g.category;
      _priority = g.priority;
      _targetDate = g.targetDate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _currentController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? now.add(const Duration(days: 365)),
      firstDate: now.add(const Duration(days: 1)),
      lastDate: DateTime(now.year + 30),
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.electricCyan,
              onPrimary: AppColors.deepNavy,
              surface: AppColors.navyLight,
              onSurface: AppColors.textPrimaryDark,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_targetDate == null) {
      _showError('Please select a target date.');
      return;
    }
    setState(() => _isLoading = true);

    final userId = AuthService.instance.currentUser?.id ?? '';
    GoalResult result;

    if (_isEditing) {
      result = await GoalService.instance.updateGoal(
        userId: userId,
        goalId: widget.existingGoal!.id,
        name: _nameController.text,
        category: _category,
        targetAmountRaw: _targetController.text,
        currentAmountRaw: _currentController.text,
        targetDate: _targetDate,
        priority: _priority,
      );
    } else {
      result = await GoalService.instance.createGoal(
        userId: userId,
        name: _nameController.text,
        category: _category,
        targetAmountRaw: _targetController.text,
        currentAmountRaw: _currentController.text,
        targetDate: _targetDate,
        priority: _priority,
      );
    }

    setState(() => _isLoading = false);

    if (result.isSuccess) {
      if (mounted) Navigator.of(context).pop(result.goal);
    } else {
      if (mounted) _showError(result.errorMessage ?? 'An error occurred.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Goal' : 'Create Goal',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor:
            isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.pagePaddingH,
            vertical: AppDimensions.space16,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Goal Name
                    _SectionLabel(label: 'Goal Name'),
                    const SizedBox(height: AppDimensions.space8),
                    _buildTextField(
                      controller: _nameController,
                      hint: 'e.g. Europe Trip, Emergency Fund',
                      isDark: isDark,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Goal name is required.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppDimensions.space20),

                    // Category
                    _SectionLabel(label: 'Category'),
                    const SizedBox(height: AppDimensions.space8),
                    _buildCategoryPicker(isDark),
                    const SizedBox(height: AppDimensions.space20),

                    // Target Amount
                    _SectionLabel(label: 'Target Amount (₹)'),
                    const SizedBox(height: AppDimensions.space8),
                    _buildTextField(
                      controller: _targetController,
                      hint: '0.00',
                      isDark: isDark,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Target amount is required.';
                        }
                        final amount = double.tryParse(v.trim());
                        if (amount == null) return 'Enter a valid number.';
                        if (amount <= 0) {
                          return 'Target amount must be greater than 0.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppDimensions.space20),

                    // Current Amount
                    _SectionLabel(label: 'Amount Already Saved (₹)'),
                    const SizedBox(height: AppDimensions.space8),
                    _buildTextField(
                      controller: _currentController,
                      hint: '0.00',
                      isDark: isDark,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Current amount is required.';
                        }
                        final current = double.tryParse(v.trim());
                        if (current == null) return 'Enter a valid number.';
                        if (current < 0) {
                          return 'Current amount cannot be negative.';
                        }
                        final target =
                            double.tryParse(_targetController.text.trim());
                        if (target != null && current > target) {
                          return 'Current amount cannot exceed target amount.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppDimensions.space20),

                    // Target Date
                    _SectionLabel(label: 'Target Date'),
                    const SizedBox(height: AppDimensions.space8),
                    _buildDatePicker(isDark),
                    const SizedBox(height: AppDimensions.space20),

                    // Priority
                    _SectionLabel(label: 'Priority'),
                    const SizedBox(height: AppDimensions.space8),
                    _buildPriorityPicker(isDark),
                    const SizedBox(height: AppDimensions.space32),

                    // Submit button
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.electricCyan,
                          foregroundColor: AppColors.deepNavy,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppDimensions.radiusMd),
                          ),
                          textStyle: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.deepNavy,
                                ),
                              )
                            : Text(_isEditing ? 'Save Changes' : 'Create Goal'),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.space24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required bool isDark,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(
        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color:
              isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
        ),
        filled: true,
        fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: BorderSide(
            color: isDark ? AppColors.navyBorder : const Color(0xFFD6E4F0),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: BorderSide(
            color: isDark ? AppColors.navyBorder : const Color(0xFFD6E4F0),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: const BorderSide(color: AppColors.electricCyan, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildCategoryPicker(bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: GoalCategory.values.map((cat) {
        final selected = _category == cat;
        return GestureDetector(
          onTap: () => setState(() => _category = cat),
          child: AnimatedContainer(
            duration: AppDimensions.durationFast,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.electricCyan.withAlpha(30)
                  : isDark
                      ? AppColors.darkSurface
                      : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              border: Border.all(
                color: selected
                    ? AppColors.electricCyan
                    : isDark
                        ? AppColors.navyBorder
                        : const Color(0xFFD6E4F0),
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _categoryIcon(cat),
                  size: 14,
                  color: selected
                      ? AppColors.electricCyan
                      : isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                ),
                const SizedBox(width: 6),
                Text(
                  cat.displayName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? AppColors.electricCyan
                        : isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDatePicker(bool isDark) {
    final hasDate = _targetDate != null;
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(
            color: isDark ? AppColors.navyBorder : const Color(0xFFD6E4F0),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 18,
              color: hasDate
                  ? AppColors.electricCyan
                  : isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
            ),
            const SizedBox(width: 10),
            Text(
              hasDate ? _formatFullDate(_targetDate!) : 'Select target date',
              style: TextStyle(
                fontSize: 14,
                fontWeight: hasDate ? FontWeight.w600 : FontWeight.w400,
                color: hasDate
                    ? isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight
                    : isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityPicker(bool isDark) {
    return Row(
      children: GoalPriority.values.map((p) {
        final selected = _priority == p;
        Color color;
        switch (p) {
          case GoalPriority.essential:
            color = AppColors.error;
            break;
          case GoalPriority.important:
            color = AppColors.warning;
            break;
          case GoalPriority.flexible:
            color = AppColors.mint;
            break;
        }
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _priority = p),
            child: AnimatedContainer(
              duration: AppDimensions.durationFast,
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: selected ? color.withAlpha(30) : Colors.transparent,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                border: Border.all(
                  color: selected
                      ? color
                      : isDark
                          ? AppColors.navyBorder
                          : const Color(0xFFD6E4F0),
                  width: selected ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    p == GoalPriority.essential
                        ? Icons.warning_rounded
                        : p == GoalPriority.important
                            ? Icons.star_rounded
                            : Icons.tune_rounded,
                    size: 18,
                    color: selected
                        ? color
                        : isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    p.displayName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? color
                          : isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _formatFullDate(DateTime dt) {
    const months = [
      'January','February','March','April','May','June',
      'July','August','September','October','November','December',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  IconData _categoryIcon(GoalCategory cat) {
    switch (cat) {
      case GoalCategory.education:
        return Icons.school_rounded;
      case GoalCategory.travel:
        return Icons.flight_rounded;
      case GoalCategory.vehicle:
        return Icons.directions_car_rounded;
      case GoalCategory.home:
        return Icons.home_rounded;
      case GoalCategory.emergencyFund:
        return Icons.shield_rounded;
      case GoalCategory.investment:
        return Icons.trending_up_rounded;
      case GoalCategory.personal:
        return Icons.star_rounded;
      case GoalCategory.other:
        return Icons.flag_rounded;
    }
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
      ),
    );
  }
}

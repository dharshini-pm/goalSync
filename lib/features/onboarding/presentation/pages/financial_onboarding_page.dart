import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../auth/services/auth_service.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';
import '../../models/financial_profile_model.dart';
import '../../services/financial_profile_service.dart';
import '../widgets/onboarding_progress_header.dart';
import '../widgets/step_about_you.dart';
import '../widgets/step_financial_position.dart';
import '../widgets/step_income.dart';
import '../widgets/step_review.dart';

/// Multi-step financial onboarding flow collecting user's financial baseline.
class FinancialOnboardingPage extends StatefulWidget {
  const FinancialOnboardingPage({super.key});

  @override
  State<FinancialOnboardingPage> createState() =>
      _FinancialOnboardingPageState();
}

class _FinancialOnboardingPageState extends State<FinancialOnboardingPage> {
  int _currentStep = 0;
  bool _isSubmitting = false;

  // Step 1 Controllers & State
  final _ageController = TextEditingController();
  String _selectedOccupation = 'Salaried Employee';
  final _otherOccupationController = TextEditingController();
  int _selectedDependents = 0;
  String? _ageError;
  String? _occupationError;

  // Step 2 Controllers & State
  final _monthlyIncomeController = TextEditingController();
  String _selectedIncomeType = 'Salary';
  final _additionalIncomeController = TextEditingController();
  String? _monthlyIncomeError;
  String? _incomeTypeError;

  // Step 3 Controllers & State
  final _savingsController = TextEditingController();
  final _fixedExpensesController = TextEditingController();
  final _variableExpensesController = TextEditingController();
  final _loanEmiController = TextEditingController();
  final _activeLoansController = TextEditingController();

  String? _savingsError;
  String? _fixedExpensesError;
  String? _variableExpensesError;
  String? _loanEmiError;
  String? _activeLoansError;

  @override
  void dispose() {
    _ageController.dispose();
    _otherOccupationController.dispose();
    _monthlyIncomeController.dispose();
    _additionalIncomeController.dispose();
    _savingsController.dispose();
    _fixedExpensesController.dispose();
    _variableExpensesController.dispose();
    _loanEmiController.dispose();
    _activeLoansController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // Validation per step
  // ─────────────────────────────────────────────────────────────

  bool _validateStep1() {
    bool isValid = true;
    setState(() {
      _ageError = null;
      _occupationError = null;
    });

    final ageText = _ageController.text.trim();
    if (ageText.isEmpty) {
      setState(() => _ageError = 'Age is required.');
      isValid = false;
    } else {
      final age = int.tryParse(ageText);
      if (age == null || age < 18 || age > 100) {
        setState(
          () => _ageError = 'Please enter a valid age between 18 and 100.',
        );
        isValid = false;
      }
    }

    if (_selectedOccupation == 'Other' &&
        _otherOccupationController.text.trim().isEmpty) {
      setState(
        () => _occupationError = 'Please describe your occupation source.',
      );
      isValid = false;
    }

    return isValid;
  }

  bool _validateStep2() {
    bool isValid = true;
    setState(() {
      _monthlyIncomeError = null;
      _incomeTypeError = null;
    });

    final incomeText = _monthlyIncomeController.text.trim();
    if (incomeText.isEmpty) {
      setState(() => _monthlyIncomeError = 'Monthly income is required.');
      isValid = false;
    } else {
      final income = double.tryParse(incomeText);
      if (income == null || income <= 0) {
        setState(
          () => _monthlyIncomeError =
              'Enter a valid monthly income greater than ₹0.',
        );
        isValid = false;
      }
    }

    if (_selectedIncomeType.isEmpty) {
      setState(() => _incomeTypeError = 'Please select your income type.');
      isValid = false;
    }

    return isValid;
  }

  bool _validateStep3() {
    bool isValid = true;
    setState(() {
      _savingsError = null;
      _fixedExpensesError = null;
      _variableExpensesError = null;
      _loanEmiError = null;
      _activeLoansError = null;
    });

    // Savings
    final savingsText = _savingsController.text.trim();
    if (savingsText.isEmpty) {
      setState(() => _savingsError = 'Current savings amount is required.');
      isValid = false;
    } else {
      final val = double.tryParse(savingsText);
      if (val == null || val < 0) {
        setState(
          () => _savingsError = 'Enter a valid savings amount (₹0 or more).',
        );
        isValid = false;
      }
    }

    // Fixed Expenses
    final fixedText = _fixedExpensesController.text.trim();
    if (fixedText.isEmpty) {
      setState(
        () => _fixedExpensesError = 'Monthly fixed obligations are required.',
      );
      isValid = false;
    } else {
      final val = double.tryParse(fixedText);
      if (val == null || val < 0) {
        setState(
          () => _fixedExpensesError =
              'Enter a valid fixed expenses amount (₹0 or more).',
        );
        isValid = false;
      }
    }

    // Variable Expenses
    final varText = _variableExpensesController.text.trim();
    if (varText.isEmpty) {
      setState(
        () =>
            _variableExpensesError = 'Monthly variable expenses are required.',
      );
      isValid = false;
    } else {
      final val = double.tryParse(varText);
      if (val == null || val < 0) {
        setState(
          () => _variableExpensesError =
              'Enter a valid variable expenses amount (₹0 or more).',
        );
        isValid = false;
      }
    }

    // Loan EMI
    final emiText = _loanEmiController.text.trim();
    if (emiText.isEmpty) {
      setState(() => _loanEmiError = 'Monthly loan EMI is required (₹0 if none).');
      isValid = false;
    } else {
      final val = double.tryParse(emiText);
      if (val == null || val < 0) {
        setState(
          () => _loanEmiError = 'Enter a valid loan EMI amount (₹0 or more).',
        );
        isValid = false;
      }
    }

    // Active Loans
    final loansText = _activeLoansController.text.trim();
    if (loansText.isEmpty) {
      setState(
        () => _activeLoansError = 'Number of active loans is required (0 if none).',
      );
      isValid = false;
    } else {
      final val = int.tryParse(loansText);
      if (val == null || val < 0) {
        setState(
          () =>
              _activeLoansError = 'Enter a valid loan count (0 or greater).',
        );
        isValid = false;
      }
    }

    return isValid;
  }

  void _handleContinue() {
    FocusScope.of(context).unfocus();

    if (_currentStep == 0) {
      if (_validateStep1()) {
        setState(() => _currentStep = 1);
      }
    } else if (_currentStep == 1) {
      if (_validateStep2()) {
        setState(() => _currentStep = 2);
      }
    } else if (_currentStep == 2) {
      if (_validateStep3()) {
        setState(() => _currentStep = 3);
      }
    } else if (_currentStep == 3) {
      _handleFinishSetup();
    }
  }

  void _handleBack() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  void _jumpToStep(int stepIndex) {
    if (stepIndex < _currentStep) {
      setState(() => _currentStep = stepIndex);
    }
  }

  Future<void> _handleFinishSetup() async {
    // Re-verify all steps before submitting
    if (!_validateStep1() || !_validateStep2() || !_validateStep3()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please correct the highlighted fields before finishing.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = AuthService.instance.currentUser;
      final userId = user?.id ?? 'default_user';

      final effectiveOccupation = _selectedOccupation == 'Other'
          ? _otherOccupationController.text.trim()
          : _selectedOccupation;

      final profile = FinancialProfile(
        userId: userId,
        age: int.parse(_ageController.text.trim()),
        occupation: effectiveOccupation,
        dependents: _selectedDependents,
        monthlyIncome: double.parse(_monthlyIncomeController.text.trim()),
        incomeType: _selectedIncomeType,
        additionalIncome:
            double.tryParse(_additionalIncomeController.text.trim()) ?? 0.0,
        currentSavings: double.parse(_savingsController.text.trim()),
        monthlyFixedExpenses:
            double.parse(_fixedExpensesController.text.trim()),
        monthlyVariableExpenses:
            double.parse(_variableExpensesController.text.trim()),
        existingLoanEmi: double.parse(_loanEmiController.text.trim()),
        activeLoansCount: int.parse(_activeLoansController.text.trim()),
        isCompleted: true,
        completedAt: DateTime.now(),
      );

      await FinancialProfileService.instance.saveProfile(profile);

      if (!mounted) return;

      // Navigate to Dashboard
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DashboardPage()),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save profile. Please try again.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final effectiveOccupation = _selectedOccupation == 'Other'
        ? (_otherOccupationController.text.trim().isNotEmpty
            ? _otherOccupationController.text.trim()
            : 'Other')
        : _selectedOccupation;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.gradientAccent,
                ),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
              child: const Icon(
                Icons.hub_rounded,
                size: 18,
                color: AppColors.deepNavy,
              ),
            ),
            const SizedBox(width: AppDimensions.space10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GoalSync',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const Text(
                  'FINANCIAL ONBOARDING',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: AppColors.electricCyan,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              children: [
                // Top Progress Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.pagePaddingH,
                    vertical: AppDimensions.space12,
                  ),
                  child: OnboardingProgressHeader(
                    currentStep: _currentStep,
                    totalSteps: 4,
                    onStepTapped: _jumpToStep,
                  ),
                ),

                const Divider(height: 1),

                // Form Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.pagePaddingH,
                      vertical: AppDimensions.space16,
                    ),
                    child: IndexedStack(
                      index: _currentStep,
                      children: [
                        StepAboutYou(
                          ageController: _ageController,
                          selectedOccupation: _selectedOccupation,
                          otherOccupationController: _otherOccupationController,
                          selectedDependents: _selectedDependents,
                          ageError: _ageError,
                          occupationError: _occupationError,
                          onOccupationChanged: (occ) {
                            setState(() {
                              _selectedOccupation = occ;
                              _occupationError = null;
                            });
                          },
                          onDependentsChanged: (deps) {
                            setState(() => _selectedDependents = deps);
                          },
                        ),
                        StepIncome(
                          monthlyIncomeController: _monthlyIncomeController,
                          selectedIncomeType: _selectedIncomeType,
                          additionalIncomeController:
                              _additionalIncomeController,
                          monthlyIncomeError: _monthlyIncomeError,
                          incomeTypeError: _incomeTypeError,
                          onIncomeTypeChanged: (type) {
                            setState(() {
                              _selectedIncomeType = type;
                              _incomeTypeError = null;
                            });
                          },
                        ),
                        StepFinancialPosition(
                          savingsController: _savingsController,
                          fixedExpensesController: _fixedExpensesController,
                          variableExpensesController:
                              _variableExpensesController,
                          loanEmiController: _loanEmiController,
                          activeLoansController: _activeLoansController,
                          savingsError: _savingsError,
                          fixedExpensesError: _fixedExpensesError,
                          variableExpensesError: _variableExpensesError,
                          loanEmiError: _loanEmiError,
                          activeLoansError: _activeLoansError,
                        ),
                        StepReview(
                          age: int.tryParse(_ageController.text.trim()) ?? 0,
                          occupation: effectiveOccupation,
                          dependents: _selectedDependents,
                          monthlyIncome: double.tryParse(
                                _monthlyIncomeController.text.trim(),
                              ) ??
                              0.0,
                          incomeType: _selectedIncomeType,
                          additionalIncome: double.tryParse(
                                _additionalIncomeController.text.trim(),
                              ) ??
                              0.0,
                          currentSavings: double.tryParse(
                                _savingsController.text.trim(),
                              ) ??
                              0.0,
                          monthlyFixedExpenses: double.tryParse(
                                _fixedExpensesController.text.trim(),
                              ) ??
                              0.0,
                          monthlyVariableExpenses: double.tryParse(
                                _variableExpensesController.text.trim(),
                              ) ??
                              0.0,
                          existingLoanEmi: double.tryParse(
                                _loanEmiController.text.trim(),
                              ) ??
                              0.0,
                          activeLoansCount: int.tryParse(
                                _activeLoansController.text.trim(),
                              ) ??
                              0,
                          onEditStep: (step) {
                            setState(() => _currentStep = step);
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Action Buttons
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.pagePaddingH,
                    vertical: AppDimensions.space16,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    border: Border(
                      top: BorderSide(
                        color: isDark
                            ? AppColors.navyBorder
                            : const Color(0xFFD6E4F0),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Back Button
                      if (_currentStep > 0) ...[
                        OutlinedButton.icon(
                          onPressed: _isSubmitting ? null : _handleBack,
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 14,
                          ),
                          label: const Text('Back'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            side: BorderSide(
                              color: isDark
                                  ? AppColors.navyBorder
                                  : const Color(0xFFCCE4F5),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppDimensions.radiusMd,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppDimensions.space12),
                      ],

                      // Continue / Finish Setup Button
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: AppColors.gradientAccent,
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusMd,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.electricCyan.withAlpha(80),
                                blurRadius: 14,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _handleContinue,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppDimensions.radiusMd,
                                ),
                              ),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.deepNavy,
                                      ),
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _currentStep == 3
                                            ? 'Finish Setup'
                                            : 'Continue',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.deepNavy,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        _currentStep == 3
                                            ? Icons.check_circle_outline_rounded
                                            : Icons.arrow_forward_rounded,
                                        color: AppColors.deepNavy,
                                        size: 18,
                                      ),
                                    ],
                                  ),
                          ),
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
    );
  }
}

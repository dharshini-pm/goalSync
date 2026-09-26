import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';

/// Step 1: About You - Collects age, occupation/income source, and dependents.
class StepAboutYou extends StatelessWidget {
  final TextEditingController ageController;
  final String selectedOccupation;
  final TextEditingController otherOccupationController;
  final int selectedDependents;
  final String? ageError;
  final String? occupationError;
  final ValueChanged<String> onOccupationChanged;
  final ValueChanged<int> onDependentsChanged;

  const StepAboutYou({
    super.key,
    required this.ageController,
    required this.selectedOccupation,
    required this.otherOccupationController,
    required this.selectedDependents,
    this.ageError,
    this.occupationError,
    required this.onOccupationChanged,
    required this.onDependentsChanged,
  });

  static const List<_OccupationOption> _occupations = [
    _OccupationOption(
      title: 'Salaried Employee',
      icon: Icons.badge_outlined,
      subtitle: 'Regular monthly compensation',
    ),
    _OccupationOption(
      title: 'Business Owner',
      icon: Icons.storefront_outlined,
      subtitle: 'Enterprise revenue & draws',
    ),
    _OccupationOption(
      title: 'Freelancer / Consultant',
      icon: Icons.laptop_mac_outlined,
      subtitle: 'Client contracts & retainers',
    ),
    _OccupationOption(
      title: 'Self-Employed Professional',
      icon: Icons.business_center_outlined,
      subtitle: 'Practicing doctor, lawyer, CA, etc.',
    ),
    _OccupationOption(
      title: 'Other',
      icon: Icons.more_horiz_rounded,
      subtitle: 'Specify your source of livelihood',
    ),
  ];

  static const List<int> _dependentsOptions = [0, 1, 2, 3, 4, 5];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Heading
          Text(
            'Tell us about yourself',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: AppDimensions.space6),
          Text(
            'This establishes your demographic baseline for personalized goal recommendations.',
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: AppDimensions.space24),

          // 1. Age Field
          _buildFieldLabel('Your Age', isDark, isRequired: true),
          const SizedBox(height: AppDimensions.space6),
          TextFormField(
            controller: ageController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            decoration: _inputDecoration(
              hintText: 'e.g. 28',
              prefixIcon: Icons.cake_outlined,
              isDark: isDark,
              errorText: ageError,
            ),
          ),
          const SizedBox(height: AppDimensions.space24),

          // 2. Occupation Field
          _buildFieldLabel(
            'Occupation / Income Source',
            isDark,
            isRequired: true,
          ),
          const SizedBox(height: AppDimensions.space6),
          if (occupationError != null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                occupationError!,
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],

          Column(
            children: _occupations.map((occ) {
              final isSelected = selectedOccupation == occ.title;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppDimensions.space8),
                child: InkWell(
                  onTap: () => onOccupationChanged(occ.title),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(AppDimensions.space12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark
                              ? AppColors.navyMid
                              : const Color(0xFFF0F9FF))
                          : (isDark
                              ? AppColors.darkSurface
                              : AppColors.lightSurface),
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMd),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.electricCyan
                            : (isDark
                                ? AppColors.navyBorder
                                : const Color(0xFFD6E4F0)),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.electricCyan.withAlpha(35),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.electricCyan.withAlpha(40)
                                : (isDark
                                    ? AppColors.navyMid
                                    : AppColors.lightSurfaceVariant),
                            borderRadius:
                                BorderRadius.circular(AppDimensions.radiusSm),
                          ),
                          child: Icon(
                            occ.icon,
                            size: 20,
                            color: isSelected
                                ? AppColors.electricCyan
                                : (isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight),
                          ),
                        ),
                        const SizedBox(width: AppDimensions.space12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                occ.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? AppColors.textPrimaryDark
                                      : AppColors.textPrimaryLight,
                                ),
                              ),
                              Text(
                                occ.subtitle,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 20,
                          color: isSelected
                              ? AppColors.electricCyan
                              : (isDark
                                  ? AppColors.textTertiaryDark
                                  : AppColors.textTertiaryLight),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          // If "Other" selected, show custom occupation input
          if (selectedOccupation == 'Other') ...[
            const SizedBox(height: AppDimensions.space8),
            TextFormField(
              controller: otherOccupationController,
              textCapitalization: TextCapitalization.words,
              decoration: _inputDecoration(
                hintText: 'Describe your occupation (e.g. Architect, Trader)',
                prefixIcon: Icons.edit_note_rounded,
                isDark: isDark,
              ),
            ),
          ],

          const SizedBox(height: AppDimensions.space24),

          // 3. Number of Dependents Field
          _buildFieldLabel(
            'Number of Dependents',
            isDark,
            isRequired: true,
          ),
          const SizedBox(height: AppDimensions.space4),
          Text(
            'Family members who depend on your financial support.',
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: AppDimensions.space12),

          Row(
            children: _dependentsOptions.map((count) {
              final isSelected = selectedDependents == count;
              final label = count == 5 ? '5+' : count.toString();
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    onTap: () => onDependentsChanged(count),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.electricCyan
                            : (isDark
                                ? AppColors.darkSurface
                                : AppColors.lightSurface),
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMd),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.electricCyan
                              : (isDark
                                  ? AppColors.navyBorder
                                  : const Color(0xFFD6E4F0)),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isSelected
                                ? AppColors.deepNavy
                                : (isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppDimensions.space24),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label, bool isDark, {bool isRequired = false}) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color:
                isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        if (isRequired)
          const Text(
            ' *',
            style: TextStyle(
              color: AppColors.electricCyan,
              fontWeight: FontWeight.w800,
            ),
          ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
    required bool isDark,
    String? errorText,
  }) {
    return InputDecoration(
      hintText: hintText,
      errorText: errorText,
      prefixIcon: Icon(
        prefixIcon,
        size: 20,
        color: isDark
            ? AppColors.textSecondaryDark
            : AppColors.textSecondaryLight,
      ),
      filled: true,
      fillColor:
          isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        borderSide: const BorderSide(
          color: AppColors.electricCyan,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        borderSide: const BorderSide(
          color: AppColors.error,
          width: 1.2,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        borderSide: const BorderSide(
          color: AppColors.error,
          width: 1.5,
        ),
      ),
    );
  }
}

class _OccupationOption {
  final String title;
  final IconData icon;
  final String subtitle;

  const _OccupationOption({
    required this.title,
    required this.icon,
    required this.subtitle,
  });
}

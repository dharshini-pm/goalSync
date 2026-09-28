import '../../../core/api/api_client.dart';
import '../models/financial_profile_model.dart';


/// Financial Profile API Service communicating with FastAPI `/financial-profile` endpoints.
class ProfileApiService {
  static ProfileApiService? _instance;
  static ProfileApiService get instance => _instance ??= ProfileApiService._();

  final ApiClient _apiClient;

  ProfileApiService._({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  /// Retrieve authenticated user's financial profile from backend.
  Future<FinancialProfile?> getProfile() async {
    try {
      final response = await _apiClient.get('/financial-profile');
      if (response == null) return null;
      return _mapBackendToProfile(response as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Create or update financial profile via backend.
  Future<FinancialProfile> saveProfile(FinancialProfile profile) async {
    final payload = {
      'age': profile.age,
      'occupation': profile.occupation,
      'dependents': profile.dependents,
      'monthlyIncome': profile.monthlyIncome,
      'incomeType': profile.incomeType,
      'additionalIncome': profile.additionalIncome,
      'currentSavings': profile.currentSavings,
      'fixedExpenses': profile.monthlyFixedExpenses,
      'variableExpenses': profile.monthlyVariableExpenses,
      'monthlyEMI': profile.existingLoanEmi,
      'activeLoans': profile.activeLoansCount,
    };

    final response = await _apiClient.post('/financial-profile', body: payload);
    return _mapBackendToProfile(response as Map<String, dynamic>);
  }


  /// Maps backend DTO to Flutter `FinancialProfile` model.
  FinancialProfile _mapBackendToProfile(Map<String, dynamic> map) {
    return FinancialProfile(
      userId: map['userId'] as String? ?? map['_id'] as String? ?? '',
      age: (map['age'] as num?)?.toInt() ?? 18,
      occupation: map['occupation'] as String? ?? '',
      dependents: (map['dependents'] as num?)?.toInt() ?? 0,
      monthlyIncome: (map['monthlyIncome'] as num?)?.toDouble() ?? 0.0,
      incomeType: map['incomeType'] as String? ?? 'Salary',
      additionalIncome: (map['additionalIncome'] as num?)?.toDouble() ?? 0.0,
      currentSavings: (map['currentSavings'] as num?)?.toDouble() ?? 0.0,
      monthlyFixedExpenses: (map['fixedExpenses'] as num?)?.toDouble() ?? 0.0,
      monthlyVariableExpenses: (map['variableExpenses'] as num?)?.toDouble() ?? 0.0,
      existingLoanEmi: (map['monthlyEMI'] as num?)?.toDouble() ?? 0.0,
      activeLoansCount: (map['activeLoans'] as num?)?.toInt() ?? 0,
      isCompleted: true,
      completedAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

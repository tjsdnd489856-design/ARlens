import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_service.dart';

class UserProfile {
  final String id;
  final String? brandId;
  final String? associatedBrandId;
  final String? ageGroup;
  final String? gender;
  final String? preferredStyle;

  UserProfile({
    required this.id,
    this.brandId,
    this.associatedBrandId,
    this.ageGroup,
    this.gender,
    this.preferredStyle,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      brandId: json['brand_id'] as String?,
      associatedBrandId: json['associated_brand_id'] as String?,
      ageGroup: json['age_group'] as String?,
      gender: json['gender'] as String?,
      preferredStyle: json['preferred_style'] as String?,
    );
  }
}

class UserProvider extends ChangeNotifier {
  UserProfile? _currentProfile;
  bool _isLoading = false;
  bool _hasCompletedOnboarding = false;

  UserProfile? get currentProfile => _currentProfile;
  bool get isLoading => _isLoading;
  bool get hasCompletedOnboarding => _hasCompletedOnboarding;

  SupabaseClient get supabase => SupabaseService.client;

  UserProvider() {
    _initOnboardingStatus();
  }

  Future<void> _initOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _hasCompletedOnboarding = prefs.getBool('has_completed_onboarding') ?? false;
    notifyListeners();
  }

  void setAnonymousProfile({
    String? ageGroup,
    String? gender,
    String? preferredStyle,
    String? associatedBrandId,
  }) {
    const String buildBrandId = String.fromEnvironment('BRAND_ID', defaultValue: 'default');
    final finalBrandId = (buildBrandId != 'default') ? buildBrandId : associatedBrandId;

    _currentProfile = UserProfile(
      id: 'anonymous',
      ageGroup: ageGroup,
      gender: gender,
      preferredStyle: preferredStyle,
      associatedBrandId: finalBrandId,
    );
    _hasCompletedOnboarding = true;
    notifyListeners();
  }

  Future<void> fetchUserProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (_currentProfile == null || _currentProfile!.id != 'anonymous') {
         _currentProfile = null;
      }
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final data = await supabase.from('profiles').select().eq('id', user.id).maybeSingle();
      if (data != null) {
        _currentProfile = UserProfile.fromJson(data);
        if (_currentProfile!.preferredStyle != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('has_completed_onboarding', true);
          _hasCompletedOnboarding = true;
        }
      } else {
        _currentProfile = UserProfile(id: user.id);
      }
      debugPrint('👤 [UserProvider] 프로필 로드 완료 (User: ${user.id})');
    } catch (e) {
      debugPrint('❌ [UserProvider] 프로필 로드 실패: $e');
      _currentProfile = UserProfile(id: user.id);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearUser() {
    _currentProfile = null;
    notifyListeners();
  }

  /// [신규] 상태 초기화 (로그아웃 시 사용)
  void clear() {
    _currentProfile = null;
    _isLoading = false;
    // 온보딩 완료 상태는 앱 재시작 전까지 유지될 수 있으나, 프로필 정보는 명확히 제거
    notifyListeners();
  }
}

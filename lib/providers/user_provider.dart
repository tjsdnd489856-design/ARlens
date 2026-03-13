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

  /// 비로그인 유저를 위한 임시 프로필 설정 (온보딩 결과 저장용)
  void setAnonymousProfile({
    String? ageGroup,
    String? gender,
    String? preferredStyle,
    String? associatedBrandId,
  }) {
    _currentProfile = UserProfile(
      id: 'anonymous',
      ageGroup: ageGroup,
      gender: gender,
      preferredStyle: preferredStyle,
      associatedBrandId: associatedBrandId,
    );
    _hasCompletedOnboarding = true;
    notifyListeners();
  }

  /// 현재 로그인된 유저의 인구통계 및 B2B 소속 정보를 로드
  Future<void> fetchUserProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      // 로그인 안 된 상태여도 기존에 설정한 익명 프로필이 있다면 유지
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
        // 로그인 유저의 프로필에 선호 스타일이 있다면 온보딩을 완료한 것으로 간주
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
}

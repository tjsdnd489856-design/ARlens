import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_service.dart';

class UserProfile {
  final String id;
  final String? name; // [Golden Master] 관리자 이름 추가
  final String? brandId;
  final String? associatedBrandId;
  final String? ageGroup;
  final String? gender;
  final String? preferredStyle;

  UserProfile({
    required this.id,
    this.name,
    this.brandId,
    this.associatedBrandId,
    this.ageGroup,
    this.gender,
    this.preferredStyle,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      name: json['name'] as String?, 
      brandId: json['brandId'] ?? json['brand_id'],
      associatedBrandId: json['associatedBrandId'] ?? json['associated_brand_id'],
      ageGroup: json['ageGroup'] ?? json['age_group'],
      gender: json['gender'],
      preferredStyle: json['preferredStyle'] ?? json['preferred_style'],
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

  Future<void> fetchUserProfile({Function(String)? onProfileLoaded}) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (_currentProfile == null || _currentProfile!.id != 'anonymous') _currentProfile = null;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final data = await supabase.from('profiles').select().eq('id', user.id).maybeSingle();
      if (data != null) {
        _currentProfile = UserProfile.fromJson(data);
        if (_currentProfile!.brandId != null && onProfileLoaded != null) {
          onProfileLoaded(_currentProfile!.brandId!);
        }
        if (_currentProfile!.preferredStyle != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('has_completed_onboarding', true);
          _hasCompletedOnboarding = true;
        }
      } else {
        _currentProfile = UserProfile(id: user.id);
      }
    } catch (e) {
      debugPrint('❌ Profile Load Error: $e');
      _currentProfile = UserProfile(id: user.id);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _currentProfile = null;
    _isLoading = false;
    notifyListeners();
  }
}

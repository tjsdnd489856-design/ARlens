import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class UserProfile {
  final String id;
  final String? brandId;
  final String? ageGroup;
  final String? gender;

  UserProfile({
    required this.id,
    this.brandId,
    this.ageGroup,
    this.gender,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      brandId: json['brand_id'] as String?,
      ageGroup: json['age_group'] as String?,
      gender: json['gender'] as String?,
    );
  }
}

class UserProvider extends ChangeNotifier {
  UserProfile? _currentProfile;
  bool _isLoading = false;

  UserProfile? get currentProfile => _currentProfile;
  bool get isLoading => _isLoading;

  SupabaseClient get supabase => SupabaseService.client;

  /// 현재 로그인된 유저의 인구통계 및 B2B 소속 정보를 로드
  Future<void> fetchUserProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      _currentProfile = null;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final data = await supabase.from('profiles').select().eq('id', user.id).maybeSingle();
      if (data != null) {
        _currentProfile = UserProfile.fromJson(data);
      } else {
        // DB에 프로필이 아직 생성되지 않은 초기 상태
        _currentProfile = UserProfile(id: user.id);
      }
      debugPrint('👤 [UserProvider] 프로필 로드 완료 (User: ${user.id})');
    } catch (e) {
      debugPrint('❌ [UserProvider] 프로필 로드 실패: $e');
      _currentProfile = UserProfile(id: user.id); // 에러 시 최소한의 세션 유지
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

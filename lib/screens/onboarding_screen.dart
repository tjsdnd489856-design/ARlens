import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/user_provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentStep = 0;
  final PageController _pageController = PageController();
  
  // UI용 한글 선택 상태
  String? _selectedAgeKo;
  String? _selectedGenderKo;
  String? _selectedStyleKo;

  bool _isSaving = false;

  // 한글 -> 영문 DB 키값 매핑 테이블
  final Map<String, String> _ageMap = {
    '10대': '10s',
    '20대': '20s',
    '30대': '30s',
    '40대 이상': '40s+',
  };

  final Map<String, String> _genderMap = {
    '여성': 'female',
    '남성': 'male',
    '기타': 'other',
  };

  final Map<String, String> _styleMap = {
    '내추럴': 'natural',
    '화려한': 'color', 
    '데일리': 'daily',
    '파티': 'party',
  };

  void _nextStep() {
    if (_currentStep == 0 && _selectedAgeKo == null) {
      _showError('나이대를 선택해 주세요.');
      return;
    }
    if (_currentStep == 1 && _selectedGenderKo == null) {
      _showError('성별을 선택해 주세요.');
      return;
    }
    if (_currentStep == 2 && _selectedStyleKo == null) {
      _showError('선호하는 스타일을 선택해 주세요.');
      return;
    }

    if (_currentStep < 2) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent, duration: const Duration(seconds: 1)),
    );
  }

  Future<void> _finishOnboarding() async {
    setState(() => _isSaving = true);
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      final dbAge = _ageMap[_selectedAgeKo];
      final dbGender = _genderMap[_selectedGenderKo];
      final dbStyle = _styleMap[_selectedStyleKo];

      // 1. 프로필 업데이트 (로그인 유저일 경우에만 DB 저장, 비로그인 시 로컬에만 유지)
      if (user != null) {
        await supabase.from('profiles').upsert({
          'id': user.id,
          'age_group': dbAge,
          'gender': dbGender,
          'preferred_style': dbStyle,
        });
        await context.read<UserProvider>().fetchUserProfile();
      } else {
        // 비로그인 상태일 때는 Provider에 임시 프로필 생성 후 저장
        context.read<UserProvider>().setAnonymousProfile(
          ageGroup: dbAge,
          gender: dbGender,
          preferredStyle: dbStyle,
        );
      }

      // 2. 온보딩 완료 상태 로컬 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_completed_onboarding', true);

      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      debugPrint('온보딩 저장 에러: $e');
      _showError('설정 저장 중 오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 프로그레스 바
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                children: List.generate(3, (index) {
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 4,
                      decoration: BoxDecoration(
                        color: index <= _currentStep ? Colors.pinkAccent : Colors.grey[200],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildChoicePage(
                    title: '반가워요!\n나이대가 어떻게 되시나요?',
                    options: _ageMap.keys.toList(),
                    selectedValue: _selectedAgeKo,
                    onSelected: (val) => setState(() => _selectedAgeKo = val),
                  ),
                  _buildChoicePage(
                    title: '성별을 알려주시면\n더 정확한 렌즈를 추천해 드려요.',
                    options: _genderMap.keys.toList(),
                    selectedValue: _selectedGenderKo,
                    onSelected: (val) => setState(() => _selectedGenderKo = val),
                  ),
                  _buildChoicePage(
                    title: '평소에 어떤 스타일의\n렌즈를 즐겨 착용하시나요?',
                    options: _styleMap.keys.toList(),
                    selectedValue: _selectedStyleKo,
                    onSelected: (val) => setState(() => _selectedStyleKo = val),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(_currentStep == 2 ? '시작하기' : '다음', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoicePage({
    required String title,
    required List<String> options,
    required String? selectedValue,
    required ValueChanged<String> onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.black87, height: 1.3),
          ),
          const SizedBox(height: 40),
          Wrap(
            spacing: 12,
            runSpacing: 16,
            children: options.map((option) {
              final isSelected = selectedValue == option;
              return ChoiceChip(
                label: Text(option),
                selected: isSelected,
                onSelected: (_) => onSelected(option),
                backgroundColor: Colors.white,
                selectedColor: Colors.pinkAccent.withOpacity(0.1),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.pinkAccent : Colors.black54,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 16,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected ? Colors.pinkAccent : Colors.grey[300]!,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                showCheckmark: false,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

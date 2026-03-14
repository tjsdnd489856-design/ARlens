import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/brand_provider.dart';
import '../providers/user_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final up = context.read<UserProvider>();
    final bp = context.read<BrandProvider>();

    // [The Masterpiece] 원자적 동기화: 프로필 로드와 테마 설정을 SplashScreen 내에서 완결
    await up.fetchUserProfile(
      onProfileLoaded: (brandId) async {
        await bp.initializeWithBrandId(brandId);
      },
    );

    // 최소 노출 시간 보장(이미 main에서 1.5초 대기했으므로 즉시 이동 가능)
    if (mounted) {
      if (up.hasCompletedOnboarding) {
        context.go('/camera');
      } else {
        context.go('/onboarding');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.watch<BrandProvider>().currentBrand;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (brand.logoUrl != null && brand.logoUrl!.isNotEmpty)
              Image.network(brand.logoUrl!, width: 120, height: 120)
            else
              const Icon(Icons.remove_red_eye, size: 80, color: Colors.pinkAccent),
            const SizedBox(height: 24),
            Text(
              brand.name,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.white),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(color: Colors.white24),
          ],
        ),
      ),
    );
  }
}

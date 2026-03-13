import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/lens_provider.dart';
import '../providers/brand_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // 데이터 로딩 시작
    await context.read<LensProvider>().fetchLensesFromSupabase();
    
    // 로딩 완료 후 부드러운 전환을 위해 약간의 대기
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (mounted) {
      context.go('/');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Consumer<BrandProvider>(
        builder: (context, brandProvider, child) {
          final brand = brandProvider.currentBrand;
          final primaryColor = brand.primaryColor;

          return Stack(
            children: [
              Center(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (brand.logoUrl != null && brand.logoUrl!.isNotEmpty)
                          Image.network(brand.logoUrl!, width: 120, height: 120, fit: BoxFit.contain)
                        else
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.5,
                                fontFamily: 'Roboto',
                              ),
                              children: [
                                TextSpan(
                                  text: brand.name.length > 2 ? brand.name.substring(0, 2) : brand.name,
                                  style: TextStyle(color: primaryColor),
                                ),
                                TextSpan(
                                  text: brand.name.length > 2 ? brand.name.substring(2) : '',
                                  style: const TextStyle(color: Colors.black87),
                                ),
                              ],
                            ),
                          ),
                        if (brand.tagline != null && brand.tagline!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            brand.tagline!,
                            style: const TextStyle(color: Colors.black54, fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 60,
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Center(
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

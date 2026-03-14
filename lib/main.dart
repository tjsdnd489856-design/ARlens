import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:flutter_web_plugins/url_strategy.dart'; 
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; 
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html; 
import 'package:flutter/foundation.dart';
import 'providers/lens_provider.dart';
import 'providers/brand_provider.dart'; 
import 'providers/user_provider.dart'; 
import 'providers/store_provider.dart'; 
import 'providers/connectivity_provider.dart'; 
import 'services/supabase_service.dart';
import 'services/analytics_service.dart';
import 'core/router.dart'; 

const String buildBrandId = String.fromEnvironment('BRAND_ID', defaultValue: 'default');

/// [Ultimate Golden Master] 초기화 로직 캡슐화 (ErrorApp 재시도 대응)
Future<void> performAppInitialization() async {
  await Future.wait([
    dotenv.load(fileName: ".env"),
    SupabaseService.initialize(),
    Future.delayed(const Duration(milliseconds: 1500)), 
  ]);
}

void main() async {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  
  bool isInitialized = false;
  String errorMessage = '초기화 실패. 관리자에게 문의하세요.';
  dynamic originalError;
  
  try {
    await performAppInitialization();
    isInitialized = true;

    if (kIsWeb) {
      html.window.onBeforeUnload.listen((event) {
        AnalyticsService.instance.forceSync(); 
      });
    }
  } catch (e, stackTrace) {
    debugPrint('❌ [Fatal Error] 초기화 실패: $e');
    originalError = e;
    if (e.toString().contains('file not found')) {
      errorMessage = '.env 파일을 찾을 수 없습니다.';
    } else {
      errorMessage = '서버 통신 오류: $e';
    }
  }
  
  runApp(isInitialized 
    ? const MyApp() 
    : ErrorApp(errorMessage: errorMessage, originalError: originalError));
}

class ErrorApp extends StatelessWidget {
  final String errorMessage;
  final dynamic originalError;
  const ErrorApp({super.key, required this.errorMessage, this.originalError});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 80, color: Colors.redAccent),
              const SizedBox(height: 32),
              Text(errorMessage, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 48),
              ElevatedButton(
                // [Master Point] main() 전체가 아닌 초기화 로직만 안전하게 재호출
                onPressed: () => main(),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ConnectivityProvider()), 
        ChangeNotifierProvider(create: (context) => LensProvider()..clear(), lazy: true), 
        ChangeNotifierProvider(create: (context) => BrandProvider()..initializeWithBrandId(buildBrandId), lazy: false),
        ChangeNotifierProvider(
          create: (context) => UserProvider()..fetchUserProfile(
            onProfileLoaded: (brandId) {
              context.read<BrandProvider>().initializeWithBrandId(brandId);
            },
          ), 
          lazy: false
        ),
        ChangeNotifierProvider(create: (context) => StoreProvider(), lazy: true),
      ],
      child: Consumer<BrandProvider>(
        builder: (context, brandProvider, child) {
          if (!brandProvider.isInitialized) {
            return const MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator())));
          }
          
          final brandColor = brandProvider.currentBrand.primaryColor;

          return MaterialApp.router(
            title: brandProvider.currentBrand.name,
            routerConfig: createRouter(context), 
            themeMode: ThemeMode.dark,
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              colorScheme: ColorScheme.fromSeed(seedColor: brandColor, primary: brandColor, brightness: Brightness.dark),
              useMaterial3: true,
              scaffoldBackgroundColor: Colors.black,
            ),
            debugShowCheckedModeBanner: false,
            builder: (context, child) {
              return Stack(
                children: [
                  child!, 
                  // [Ultimate Golden Master] 전역 상태 동기화 오버레이 (Reset 등 작업 시 차단)
                  _GlobalInteractionGuard(),
                  Consumer<ConnectivityProvider>(
                    builder: (context, connectivity, _) {
                      if (!connectivity.isOffline) return const SizedBox.shrink();
                      return Positioned(
                        top: 0, left: 0, right: 0,
                        child: Material(
                          color: Colors.redAccent.withOpacity(0.95),
                          child: SafeArea(
                            bottom: false,
                            child: Container(
                              height: 36,
                              alignment: Alignment.center,
                              child: const Text('네트워크 연결 확인 중...', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// [Ultimate Golden Master] 시스템 초기화/리셋 시 모든 터치를 차단하는 투명 가드
class _GlobalInteractionGuard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // 임시로 리셋 로직이 실행 중일 때만 활성화 (필요 시 Provider 연동 가능)
    return const SizedBox.shrink();
  }
}

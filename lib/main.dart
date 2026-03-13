import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // env 지원 추가
import 'package:shared_preferences/shared_preferences.dart'; 
import 'providers/lens_provider.dart';
import 'providers/brand_provider.dart'; 
import 'providers/user_provider.dart'; 
import 'providers/store_provider.dart'; // 매장 프로바이더 추가
import 'screens/camera_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart'; 
import 'screens/map_screen.dart'; // 지도 화면 추가
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/admin_add_lens_screen.dart';
import 'screens/admin/login_screen.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. 환경 변수 로드
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print('환경 변수 로드 실패: $e');
  }
  
  // 2. Supabase 초기화
  await SupabaseService.initialize();
  
  runApp(const MyApp());
}

final GoRouter _router = GoRouter(
  initialLocation: '/splash',
  redirect: (BuildContext context, GoRouterState state) async {
    final bool loggedIn = Supabase.instance.client.auth.currentUser != null;
    final bool loggingIn = state.matchedLocation == '/login';
    
    // 어드민 페이지 접근 제어
    if (state.matchedLocation.startsWith('/admin')) {
      if (!loggedIn) return '/login';
    }
    if (loggingIn && loggedIn) return '/admin';

    // 온보딩 로직 분기
    if (state.matchedLocation == '/') {
       final prefs = await SharedPreferences.getInstance();
       final hasCompletedOnboarding = prefs.getBool('has_completed_onboarding') ?? false;
       if (!hasCompletedOnboarding) {
         return '/onboarding';
       }
    }

    return null;
  },
  routes: <RouteBase>[
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return const CameraScreen();
      },
    ),
    GoRoute(
      path: '/map',
      builder: (BuildContext context, GoRouterState state) {
        return const MapScreen();
      },
    ),
    GoRoute(
      path: '/login',
      builder: (BuildContext context, GoRouterState state) {
        return const AdminLoginScreen();
      },
    ),
    GoRoute(
      path: '/admin',
      builder: (BuildContext context, GoRouterState state) {
        return const AdminDashboardScreen();
      },
      routes: <RouteBase>[
        GoRoute(
          path: 'add',
          builder: (BuildContext context, GoRouterState state) {
            return const AdminAddLensScreen();
          },
        ),
      ],
    ),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MultiProvider를 통해 모든 상태 주입
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => LensProvider(), lazy: true),
        ChangeNotifierProvider(create: (context) => BrandProvider(), lazy: true),
        ChangeNotifierProvider(create: (context) => UserProvider()..fetchUserProfile(), lazy: false),
        ChangeNotifierProvider(create: (context) => StoreProvider(), lazy: true),
      ],
      child: Consumer<BrandProvider>(
        builder: (context, brandProvider, child) {
          final brandColor = brandProvider.currentBrand.primaryColor;
          
          return MaterialApp.router(
            title: 'ARlens',
            routerConfig: _router,
            // [런칭 최적화] 다크 테마 고정 및 브랜드 컬러 동적 연동
            themeMode: ThemeMode.dark,
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              colorScheme: ColorScheme.fromSeed(
                seedColor: brandColor,
                primary: brandColor,
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
              scaffoldBackgroundColor: Colors.black,
            ),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // env 지원 추가
import 'providers/lens_provider.dart';
import 'providers/brand_provider.dart'; // 브랜드 프로바이더 추가
import 'screens/camera_screen.dart';
import 'screens/splash_screen.dart';
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
  redirect: (BuildContext context, GoRouterState state) {
    final bool loggedIn = Supabase.instance.client.auth.currentUser != null;
    final bool loggingIn = state.matchedLocation == '/login';
    if (state.matchedLocation.startsWith('/admin')) {
      if (!loggedIn) return '/login';
    }
    if (loggingIn && loggedIn) return '/admin';
    return null;
  },
  routes: <RouteBase>[
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return const CameraScreen();
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
    // MultiProvider를 통해 B2B 브랜드 상태와 렌즈 상태를 모두 주입
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => LensProvider(), lazy: true),
        ChangeNotifierProvider(create: (context) => BrandProvider(), lazy: true),
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

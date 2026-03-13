import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'providers/lens_provider.dart';
import 'providers/brand_provider.dart'; 
import 'providers/user_provider.dart'; 
import 'providers/store_provider.dart';
import 'screens/camera_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart'; 
import 'screens/map_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/admin_add_lens_screen.dart';
import 'screens/admin/login_screen.dart';
import 'services/supabase_service.dart';

void runARlensApp(String brandId) async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. 환경 변수 로드
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print('환경 변수 로드 실패: $e');
  }
  
  // 2. Supabase 초기화
  await SupabaseService.initialize();
  
  runApp(ARlensApp(brandId: brandId));
}

final GoRouter _router = GoRouter(
  initialLocation: '/splash',
  redirect: (BuildContext context, GoRouterState state) async {
    final bool loggedIn = Supabase.instance.client.auth.currentUser != null;
    final bool loggingIn = state.matchedLocation == '/login';
    
    if (state.matchedLocation.startsWith('/admin')) {
      if (!loggedIn) return '/login';
    }
    if (loggingIn && loggedIn) return '/admin';

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
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
    GoRoute(path: '/', builder: (context, state) => const CameraScreen()),
    GoRoute(path: '/map', builder: (context, state) => const MapScreen()),
    GoRoute(path: '/login', builder: (context, state) => const AdminLoginScreen()),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminDashboardScreen(),
      routes: [
        GoRoute(path: 'add', builder: (context, state) => const AdminAddLensScreen()),
      ],
    ),
  ],
);

class ARlensApp extends StatelessWidget {
  final String brandId;
  const ARlensApp({super.key, required this.brandId});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => LensProvider(), lazy: true),
        ChangeNotifierProvider(
          create: (context) => BrandProvider()..initializeWithBrandId(brandId), 
          lazy: false,
        ),
        ChangeNotifierProvider(create: (context) => UserProvider()..fetchUserProfile(), lazy: false),
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
            routerConfig: _router,
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

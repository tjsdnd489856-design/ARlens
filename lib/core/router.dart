import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart'; // [Grand Completion] 추가
import '../screens/camera_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/onboarding_screen.dart'; 
import '../screens/map_screen.dart'; 
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/admin/admin_add_lens_screen.dart';
import '../screens/admin/login_screen.dart';
import '../models/lens_model.dart';
import '../providers/user_provider.dart'; // [Grand Completion] 추가

class RouterRefreshStream extends ChangeNotifier {
  RouterRefreshStream(Stream<AuthState> stream, BuildContext context) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((state) {
      // [Grand Completion] 인증 상태가 변하면 즉시 프로필 갱신 시도
      if (state.event == AuthChangeEvent.signedIn) {
        context.read<UserProvider>().fetchUserProfile();
      } else if (state.event == AuthChangeEvent.signedOut) {
        context.read<UserProvider>().clear();
      }
      notifyListeners();
    });
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

// 라우터를 함수형으로 변경하여 context 접근 가능하게 함 (필요시)
GoRouter createRouter(BuildContext context) => GoRouter(
  initialLocation: kIsWeb ? '/login' : '/splash',
  refreshListenable: RouterRefreshStream(Supabase.instance.client.auth.onAuthStateChange, context),
  redirect: (BuildContext context, GoRouterState state) async {
    final bool loggedIn = Supabase.instance.client.auth.currentUser != null;
    final bool loggingIn = state.matchedLocation == '/login';
    
    if (kIsWeb) {
      if (state.matchedLocation == '/') return loggedIn ? '/admin' : '/login';
      if (!loggedIn && state.matchedLocation != '/login') return '/login';
    }

    if (state.matchedLocation.startsWith('/admin')) {
      if (!loggedIn) return '/login';
    }
    if (loggingIn && loggedIn) return '/admin';

    if (!kIsWeb && state.matchedLocation == '/') {
       final prefs = await SharedPreferences.getInstance();
       final hasCompletedOnboarding = prefs.getBool('has_completed_onboarding') ?? false;
       if (!hasCompletedOnboarding) return '/onboarding';
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
        GoRoute(
          path: 'add',
          builder: (context, state) {
            final lens = state.extra as Lens?;
            return AdminAddLensScreen(existingLens: lens);
          },
        ),
      ],
    ),
  ],
);

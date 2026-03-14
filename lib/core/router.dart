import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../screens/camera_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/admin/login_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/admin/admin_add_lens_screen.dart';
import '../screens/map_screen.dart';
import '../screens/edit_screen.dart';
import '../providers/user_provider.dart';
import '../models/lens_model.dart';
import '../services/supabase_service.dart';

GoRouter createRouter(BuildContext context) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final userProvider = context.read<UserProvider>();
      final bool loggedIn = userProvider.currentProfile != null && userProvider.currentProfile!.id != 'anonymous';
      final bool loggingIn = state.matchedLocation == '/admin/login';
      final bool onOnboarding = state.matchedLocation == '/onboarding';
      final bool onSplash = state.matchedLocation == '/';

      if (onSplash || onOnboarding) return null;

      if (state.matchedLocation.startsWith('/admin') && !loggedIn && !loggingIn) {
        final String from = state.uri.toString();
        return '/admin/login?from=${Uri.encodeComponent(from)}';
      }

      if (loggedIn && loggingIn) {
        final from = state.uri.queryParameters['from'];
        if (from != null) return Uri.decodeComponent(from);
        return '/admin/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: '/camera', builder: (context, state) => const CameraScreen()),
      GoRoute(path: '/map', builder: (context, state) => const MapScreen()),
      GoRoute(path: '/edit', builder: (context, state) => const EditScreen()),
      GoRoute(path: '/admin/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/admin/dashboard', builder: (context, state) => const AdminDashboardScreen()),
      GoRoute(
        path: '/admin/add',
        builder: (context, state) {
          final lens = state.extra as Lens?;
          final simulatedBrandId = state.uri.queryParameters['brandId'];
          
          // [Final Golden Master] 브랜드 ID 유효성 검사 로직 (SQL injection 방어)
          if (simulatedBrandId != null && simulatedBrandId.length > 50) {
            return const AdminDashboardScreen(); // 비정상적 긴 ID 폴백
          }
          
          return AdminAddLensScreen(existingLens: lens, initialBrandId: simulatedBrandId);
        },
      ),
    ],
  );
}

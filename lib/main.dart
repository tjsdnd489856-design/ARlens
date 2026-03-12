import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'providers/lens_provider.dart';
import 'screens/camera_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/admin_add_lens_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase 초기화 오류 (설정이 필요할 수 있습니다): $e');
  }

  runApp(
    ChangeNotifierProvider(
      create: (context) => LensProvider(),
      child: const MyApp(),
    ),
  );
}

// 비밀 라우팅 설정 (일반 유저가 못 보게 주소로 분리)
final GoRouter _router = GoRouter(
  routes: <RouteBase>[
    // 일반 사용자가 보는 기본 카메라 화면
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return const CameraScreen();
      },
    ),
    // 관리자만 아는 비밀 주소를 치고 들어왔을 때 보이는 대시보드
    GoRoute(
      path: '/admin-secret-page',
      builder: (BuildContext context, GoRouterState state) {
        return const AdminDashboardScreen();
      },
      routes: <RouteBase>[
        // 대시보드 안에서 신규 렌즈 추가 버튼을 눌렀을 때 이동하는 경로
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
    // MaterialApp.router를 사용해 우리가 만든 라우터(주소 체계)를 앱에 적용합니다.
    return MaterialApp.router(
      title: 'ARlens',
      routerConfig: _router,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pinkAccent),
        useMaterial3: true,
      ),
      // 우측 상단 디버그 띠 숨기기
      debugShowCheckedModeBanner: false,
    );
  }
}

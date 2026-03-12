import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/lens_provider.dart';
import 'screens/camera_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/admin_add_lens_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      debugPrint("dotenv 로드 실패 (무시됨): $e");
    }

    try {
      await Supabase.initialize(
        url:
            dotenv.env['SUPABASE_URL'] ??
            'https://zelxqkkasuomhbamzfrz.supabase.co',
        anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
      );
      debugPrint("🚀 [System] Supabase Engine Initialized Successfully");
    } catch (e) {
      debugPrint("❌ [System] Supabase Init Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            home: Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: CircularProgressIndicator(color: Colors.pinkAccent),
              ),
            ),
            debugShowCheckedModeBanner: false,
          );
        }

        return ChangeNotifierProvider(
          create: (context) => LensProvider(),
          child: MaterialApp.router(
            title: 'ARlens',
            routerConfig: _router,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.pinkAccent),
              useMaterial3: true,
            ),
            debugShowCheckedModeBanner: false,
          ),
        );
      },
    );
  }
}

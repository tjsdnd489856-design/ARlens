import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/lens_provider.dart';
import 'screens/camera_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/admin_add_lens_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool isSupabaseInitialized = false;

  try {
    // .env 파일 로드를 시도하되 실패해도 앱이 죽지 않도록 안전하게 처리합니다.
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('.env 파일 로드 실패 (또는 파일 없음): $e');
  }

  try {
    // 환경변수가 없을 경우 빈 문자열을 넘기면 에러가 발생하므로,
    // 초기화 실패를 방지하기 위해 URL 형식을 맞춘 플레이스홀더를 제공합니다.
    final supabaseUrl =
        dotenv.env['SUPABASE_URL'] ?? 'https://placeholder.supabase.co';
    final supabaseKey = dotenv.env['SUPABASE_ANON_KEY'] ?? 'placeholder_key';

    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
    isSupabaseInitialized = true;
  } catch (e) {
    debugPrint('Supabase 초기화 오류: $e');
    isSupabaseInitialized = false;
  }

  // 초기화 실패 시 빈 화면 대신 진행 상태를 알려주는 화면을 띄웁니다.
  if (!isSupabaseInitialized) {
    runApp(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('서버 연결 중...'))),
      ),
    );
    return;
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

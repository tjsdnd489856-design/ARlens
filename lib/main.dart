import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart'; 
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; 
import 'providers/lens_provider.dart';
import 'providers/brand_provider.dart'; 
import 'providers/user_provider.dart'; 
import 'providers/store_provider.dart'; 
import 'services/supabase_service.dart';
import 'core/router.dart'; 

const String buildBrandId = String.fromEnvironment('BRAND_ID', defaultValue: 'default');

void main() async {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  
  bool isInitialized = false;
  String errorMessage = '초기화 실패. 관리자에게 문의하세요.';
  
  try {
    await dotenv.load(fileName: ".env");
    await SupabaseService.initialize();
    isInitialized = true;
  } catch (e) {
    debugPrint('❌ [Fatal Error] 초기화 실패: $e');
    if (e.toString().contains('file not found')) {
      errorMessage = '.env 파일을 찾을 수 없습니다. 환경 설정을 확인해 주세요.';
    } else if (e.toString().contains('SocketException') || e.toString().contains('network')) {
      errorMessage = '네트워크 연결이 원활하지 않습니다. 인터넷 연결을 확인해 주세요.';
    } else {
      errorMessage = '서버 통신 오류가 발생했습니다: $e';
    }
  }
  
  if (isInitialized) {
    runApp(const MyApp());
  } else {
    runApp(ErrorApp(errorMessage: errorMessage));
  }
}

class ErrorApp extends StatelessWidget {
  final String errorMessage;
  const ErrorApp({super.key, required this.errorMessage});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
                const SizedBox(height: 24),
                Text(
                  '앱을 시작할 수 없습니다',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => main(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('다시 시도', style: TextStyle(fontSize: 18)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
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
        ChangeNotifierProvider(create: (context) => LensProvider(), lazy: true),
        ChangeNotifierProvider(create: (context) => BrandProvider()..initializeWithBrandId(buildBrandId), lazy: false),
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
            routerConfig: createRouter(context), // [교정] context를 전달하는 팩토리 함수 사용
            themeMode: ThemeMode.dark,
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              colorScheme: ColorScheme.fromSeed(seedColor: brandColor, primary: brandColor, brightness: Brightness.dark),
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

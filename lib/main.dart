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
  try {
    await dotenv.load(fileName: ".env");
    await SupabaseService.initialize();
    isInitialized = true;
  } catch (e) {
    debugPrint('❌ [Fatal Error] 초기화 실패: $e');
  }
  
  if (isInitialized) {
    runApp(const MyApp());
  } else {
    runApp(const ErrorApp());
  }
}

class ErrorApp extends StatelessWidget {
  const ErrorApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: Scaffold(body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.error, size: 64, color: Colors.red), const SizedBox(height: 16), const Text('초기화 실패. .env 파일을 확인해 주세요.'), ElevatedButton(onPressed: () => main(), child: const Text('재시도'))]))));
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

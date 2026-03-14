import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'providers/lens_provider.dart';
import 'providers/brand_provider.dart'; 
import 'providers/user_provider.dart'; 
import 'providers/store_provider.dart';
import 'services/supabase_service.dart';
import 'core/router.dart'; 

void runARlensApp(String brandId) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('환경 변수 로드 실패: $e');
  }
  await SupabaseService.initialize();
  runApp(ARlensApp(brandId: brandId));
}

class ARlensApp extends StatelessWidget {
  final String brandId;
  const ARlensApp({super.key, required this.brandId});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => LensProvider(), lazy: true),
        ChangeNotifierProvider(create: (context) => BrandProvider()..initializeWithBrandId(brandId), lazy: false),
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
            routerConfig: createRouter(context), // [교정] 통합 라우터 팩토리 사용
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

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/brand_provider.dart';
import '../../models/brand_model.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    try {
      // [The Final One] 로그인 리다이렉트 경로 복구용 파라미터 획득
      final state = GoRouterState.of(context);
      final String? redirectTo = state.uri.queryParameters['from'];

      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      
      if (mounted) {
        await context.read<UserProvider>().fetchUserProfile();
        final userProfile = context.read<UserProvider>().currentProfile;

        if (userProfile != null && userProfile.brandId != null && userProfile.brandId!.isNotEmpty && userProfile.brandId != 'admin') {
          final supabase = Supabase.instance.client;
          final brandData = await supabase.from('brands').select().eq('id', userProfile.brandId!).maybeSingle();
          if (brandData != null && mounted) {
            final brand = Brand.fromJson(brandData);
            context.read<BrandProvider>().setBrand(brand);
          }
        } else {
          if (mounted) context.read<BrandProvider>().resetToDefault();
        }

        if (mounted) {
          // [The Final One] 복구할 경로가 있으면 해당 경로로, 없으면 기본 대시보드로 이동
          if (redirectTo != null && redirectTo.isNotEmpty) {
            context.go(redirectTo);
          } else {
            context.go('/admin');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('로그인 실패: 이메일 또는 비밀번호를 확인하세요'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kIsWeb ? const Color(0xFFF8F9FA) : Colors.white,
      appBar: kIsWeb ? null : AppBar(
        title: const Text('Admin Login', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450),
            padding: kIsWeb ? const EdgeInsets.all(40.0) : EdgeInsets.zero,
            decoration: kIsWeb ? BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ) : null,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.lock_outline, size: 80, color: Colors.pinkAccent),
                const SizedBox(height: 40),
                if (kIsWeb) ...[
                  const Text(
                    'ARlens Admin',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D)),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '관리자 계정으로 로그인하세요',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 40),
                ],
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.lock_open_outlined),
                  ),
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _signIn(),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _signIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('로그인', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),
                if (!kIsWeb)
                  TextButton(
                    onPressed: () => context.go('/'),
                    child: const Text('카메라 화면으로 돌아가기', style: TextStyle(color: Colors.grey)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

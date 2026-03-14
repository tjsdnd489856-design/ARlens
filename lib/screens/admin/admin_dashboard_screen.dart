import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/lens_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/brand_provider.dart';
import '../../models/lens_model.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LensProvider>().fetchLensesFromSupabase();
    });
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.watch<LensProvider>();
    final up = context.watch<UserProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              SupabaseService.client.auth.signOut();
              context.go('/');
            },
          )
        ],
      ),
      body: lp.isLoading 
        ? const Center(child: CircularProgressIndicator())
        : GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.8,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: lp.lenses.length,
            itemBuilder: (context, index) {
              final lens = lp.lenses[index];
              return Card(
                child: Column(
                  children: [
                    Expanded(
                      child: lens.thumbnailUrl.isNotEmpty
                        ? CachedNetworkImage(imageUrl: lens.thumbnailUrl, fit: BoxFit.cover)
                        : const Icon(Icons.image, size: 50),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(lens.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => context.push('/admin/add', extra: lens),
                    )
                  ],
                ),
              );
            },
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/admin/add'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

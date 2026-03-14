import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:provider/provider.dart';
import '../providers/brand_provider.dart';

class BrandShimmer extends StatelessWidget {
  final double? width;
  final double? height;
  final BoxShape shape;
  final double borderRadius;

  const BrandShimmer({
    super.key,
    this.width,
    this.height,
    this.shape = BoxShape.rectangle,
    this.borderRadius = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    final brand = context.watch<BrandProvider>().currentBrand;
    final primaryColor = brand.primaryColor;

    // [Grand Master] 브랜드 컬러를 약하게 섞은 세련된 쉐이머 그라데이션
    return Shimmer.fromColors(
      baseColor: primaryColor.withOpacity(0.1),
      highlightColor: primaryColor.withOpacity(0.05),
      period: const Duration(milliseconds: 1500),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: shape,
          borderRadius: shape == BoxShape.circle ? null : BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class BrandImageError extends StatelessWidget {
  final double size;
  final String message;

  const BrandImageError({
    super.key,
    this.size = 40,
    this.message = '이미지 준비 중',
  });

  @override
  Widget build(BuildContext context) {
    final brand = context.watch<BrandProvider>().currentBrand;
    final primaryColor = brand.primaryColor;

    return Container(
      color: Colors.grey[50],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported_outlined, color: primaryColor.withOpacity(0.3), size: size),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              color: Colors.black26,
              fontSize: size * 0.3,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

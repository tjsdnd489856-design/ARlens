import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/brand_model.dart';
import '../models/lens_model.dart';
import 'package:http/http.dart' as http;

class ReportService {
  ReportService._privateConstructor();
  static final ReportService _instance = ReportService._privateConstructor();
  static ReportService get instance => _instance;

  Future<void> generateAndPrintBrandReport({
    required Brand brand,
    required List<Lens> lenses,
    required Map<String, dynamic> stats,
  }) async {
    final pdf = pw.Document();

    // 1. 폰트 로드 (한글 지원을 위해 기본 폰트를 Roboto 혹은 NotoSans로 시도)
    pw.Font? regularFont;
    pw.Font? boldFont;
    try {
      final fontData = await rootBundle.load("fonts/Pretendard-Regular.ttf");
      regularFont = pw.Font.ttf(fontData);
      final boldFontData = await rootBundle.load("fonts/Pretendard-Bold.ttf");
      boldFont = pw.Font.ttf(boldFontData);
    } catch (e) {
      // 폰트가 에셋에 없으면 기본 제공 폰트로 폴백
      regularFont = null; 
      boldFont = null;
    }

    final theme = pw.ThemeData.withFont(
      base: regularFont,
      bold: boldFont,
    );

    // 브랜드 컬러 변환 (Flutter Color -> PdfColor)
    final brandColor = PdfColor(
      brand.primaryColor.red / 255.0,
      brand.primaryColor.green / 255.0,
      brand.primaryColor.blue / 255.0,
    );

    // 로고 이미지 로드 (웹 URL)
    pw.MemoryImage? logoImage;
    if (brand.logoUrl != null && brand.logoUrl!.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(brand.logoUrl!));
        if (response.statusCode == 200) {
          logoImage = pw.MemoryImage(response.bodyBytes);
        }
      } catch (e) {
        print('로고 로드 실패: $e');
      }
    }

    // 통계 변수 추출
    final totalTryOns = stats['totalTryOns'] ?? 0;
    final avgDuration = stats['avgDuration'] ?? 0.0;
    final activeUsers = stats['activeUsers'] ?? 0;

    // 인기 렌즈 정렬 (TryOn 기준 내림차순, 최대 5개)
    List<Lens> topLenses = List.from(lenses);
    topLenses.sort((a, b) => b.tryOnCount.compareTo(a.tryOnCount));
    topLenses = topLenses.take(5).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'ARlens Analytics Report',
                        style: pw.TextStyle(
                          color: brandColor,
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Generated on: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                        style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10),
                      ),
                    ],
                  ),
                  if (logoImage != null)
                    pw.Container(
                      height: 40,
                      child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                    )
                  else
                    pw.Text(
                      brand.name,
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                    ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Divider(color: brandColor, thickness: 2),
              pw.SizedBox(height: 24),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            // 1. Performance Summary
            pw.Text('Performance Summary', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
            pw.SizedBox(height: 12),
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: brandColor, width: 1),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              padding: const pw.EdgeInsets.all(16),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem('Total Try-ons', '$totalTryOns', brandColor),
                  _buildSummaryItem('Avg Duration', '${avgDuration.toStringAsFixed(1)}s', brandColor),
                  _buildSummaryItem('Active Users', '$activeUsers', brandColor),
                ],
              ),
            ),
            pw.SizedBox(height: 32),

            // 2. Top Lenses Table
            pw.Text('Top 5 Popular Lenses', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
            pw.SizedBox(height: 12),
            pw.TableHelper.fromTextArray(
              context: context,
              border: pw.TableBorder.all(color: PdfColors.grey300),
              headerAlignment: pw.Alignment.centerLeft,
              headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold),
              headerDecoration: pw.BoxDecoration(color: brandColor),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.all(8),
              data: [
                ['Rank', 'Lens Name', 'Tags', 'Try-ons'],
                ...topLenses.asMap().entries.map((entry) {
                  int idx = entry.key;
                  Lens lens = entry.value;
                  return [
                    '${idx + 1}',
                    lens.name,
                    lens.tags.join(', '),
                    '${lens.tryOnCount}',
                  ];
                }),
              ],
            ),
            pw.SizedBox(height: 32),
            
            // 3. Insight & Conclusion
            pw.Text('Business Insight', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
            pw.SizedBox(height: 12),
            pw.Text(
              '${brand.name} has generated $totalTryOns virtual interactions through the ARlens platform. '
              'The most engaged lens is "${topLenses.isNotEmpty ? topLenses.first.name : 'N/A'}", indicating strong user interest in this style. '
              'Average dwell time per interaction is ${avgDuration.toStringAsFixed(1)} seconds, proving high content immersion.',
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.black, lineSpacing: 1.5),
            ),
          ];
        },
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('ARlens B2B Analytics', style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10)),
                  pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10)),
                ],
              ),
            ],
          );
        },
      ),
    );

    // PDF 뷰어/인쇄 다이얼로그 띄우기
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '${brand.name}_Analytics_Report.pdf',
    );
  }

  pw.Widget _buildSummaryItem(String title, String value, PdfColor brandColor) {
    return pw.Column(
      children: [
        pw.Text(title, style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 12)),
        pw.SizedBox(height: 8),
        pw.Text(value, style: pw.TextStyle(color: brandColor, fontSize: 24, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }
}

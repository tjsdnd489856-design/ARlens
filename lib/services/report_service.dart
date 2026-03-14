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

  String _mapTagToKorean(String tag) {
    final lowerTag = tag.toLowerCase();
    switch (lowerTag) {
      case '10s': return '10대';
      case '20s': return '20대';
      case '30s': return '30대';
      case '40s+': return '40대 이상';
      case 'female': return '여성';
      case 'male': return '남성';
      case 'other': return '기타';
      case 'natural': return '내추럴';
      case 'color': return '화려한';
      case 'daily': return '데일리';
      case 'party': return '파티';
      default: return tag;
    }
  }

  Future<void> generateAndPrintBrandReport({
    required Brand brand,
    required List<Lens> lenses,
    required Map<String, dynamic> stats,
  }) async {
    final pdf = pw.Document();

    pw.Font? regularFont;
    pw.Font? boldFont;
    try {
      final fontData = await rootBundle.load("assets/fonts/Pretendard-Regular.ttf");
      regularFont = pw.Font.ttf(fontData);
      final boldFontData = await rootBundle.load("assets/fonts/Pretendard-Bold.ttf");
      boldFont = pw.Font.ttf(boldFontData);
    } catch (e) {
      print('⚠️ PDF 폰트 로드 실패: $e');
      regularFont = null; 
      boldFont = null;
    }

    final theme = pw.ThemeData.withFont(
      base: regularFont,
      bold: boldFont,
    );

    final brandColor = PdfColor(
      brand.primaryColor.red / 255.0,
      brand.primaryColor.green / 255.0,
      brand.primaryColor.blue / 255.0,
    );

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

    final totalTryOns = stats['totalTryOns'] ?? 0;
    final avgDuration = stats['avgDuration'] ?? 0.0;
    final activeUsers = stats['activeUsers'] ?? 0;

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
                    crossAxisAlignment: pw.CrossAxisAlignment.start, // [교정] pw. 접두사 적용 여부 확인
                    children: [
                      pw.Text(
                        'ARlens 브랜드 분석 보고서',
                        style: pw.TextStyle(
                          color: brandColor,
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '생성일시: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
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
            pw.Text('핵심 성과 요약', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
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
                  _buildSummaryItem('누적 체험 수', '$totalTryOns', brandColor),
                  _buildSummaryItem('평균 착용 시간', '${avgDuration.toStringAsFixed(1)}s', brandColor),
                  _buildSummaryItem('활성 유저', '$activeUsers', brandColor),
                ],
              ),
            ),
            pw.SizedBox(height: 32),

            pw.Text('인기 제품 TOP 5', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
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
                ['순위', '렌즈명', '태그', '착용 수'],
                ...topLenses.asMap().entries.map((entry) {
                  int idx = entry.key;
                  Lens lens = entry.value;
                  final koreanTags = lens.tags.map((t) => _mapTagToKorean(t)).join(', ');
                  return [
                    '${idx + 1}',
                    lens.name,
                    koreanTags,
                    '${lens.tryOnCount}',
                  ];
                }),
              ],
            ),
            pw.SizedBox(height: 32),
            
            pw.Text('비즈니스 인사이트', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
            pw.SizedBox(height: 12),
            pw.Text(
              '${brand.name} 브랜드는 ARlens 플랫폼을 통해 총 $totalTryOns 회의 가상 착용 인터랙션을 발생시켰습니다. '
              '가장 참여도가 높은 렌즈는 "${topLenses.isNotEmpty ? topLenses.first.name : 'N/A'}"이며, 유저들의 높은 선호도를 보여줍니다. '
              '세션당 평균 체류 시간은 ${avgDuration.toStringAsFixed(1)}초로, 콘텐츠에 대한 높은 몰입도와 구매 전환 가능성을 입증합니다.',
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
                  pw.Text('ARlens B2B 분석 리포트', style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10)),
                  pw.Text('페이지 ${context.pageNumber} / ${context.pagesCount}', style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10)),
                ],
              ),
            ],
          );
        },
      ),
    );

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

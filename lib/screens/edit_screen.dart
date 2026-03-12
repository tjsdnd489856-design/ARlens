import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';

// 손가락으로 그린 선의 정보(위치와 색상)를 담는 작은 상자
class DrawnLine {
  final List<Offset> points;
  final Color color;
  DrawnLine(this.points, this.color);
}

// 화면에 올려진 스티커의 정보(모양, 위치)를 담는 상자
class StickerData {
  final String text;
  Offset position;
  StickerData(this.text, this.position);
}

class EditScreen extends StatefulWidget {
  final Uint8List capturedImage; // 카메라 화면에서 넘겨받은 사진 데이터

  const EditScreen({super.key, required this.capturedImage});

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  // 꾸민 화면 전체를 다시 캡처해서 갤러리에 저장하기 위한 이름표
  final GlobalKey _editGlobalKey = GlobalKey();

  // 그림 그리기 관련 상태
  List<DrawnLine> _lines = [];
  List<Offset> _currentLine = [];
  Color _selectedColor = Colors.pinkAccent; // 기본 펜 색상

  // 스티커 관련 상태
  List<StickerData> _stickers = [];

  // Y2K 다꾸 느낌의 색상 목록
  final List<Color> _penColors = [
    Colors.pinkAccent,
    Colors.blueAccent,
    Colors.greenAccent,
    Colors.yellowAccent,
    Colors.white,
  ];

  // 더미 스티커 (이모지) 목록
  final List<String> _availableStickers = ['💖', '✨', '🍒', '🦋', '🔥'];

  // 화면 전체를 캡처해서 스마트폰 사진첩에 저장하는 함수 (gal 패키지 사용)
  Future<void> _saveToGallery() async {
    try {
      // 1. 저장 권한 확인 및 요청 (gal 패키지 내장 기능 활용)
      bool hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) {
        hasAccess = await Gal.requestAccess(toAlbum: true);
      }

      // 그래도 권한이 없다면 중단합니다.
      if (!hasAccess) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('사진 저장 권한이 필요합니다.')));
        return;
      }

      // 2. 화면 캡처
      RenderRepaintBoundary boundary =
          _editGlobalKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      // 3. 갤러리에 캡처된 이미지 바이트 저장
      await Gal.putImageBytes(pngBytes);

      if (!mounted) return;
      // 4. 성공 시 Y2K 감성 알림 띄우기
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '갤러리에 저장 완료! 📸',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                BoxShadow(
                  color: Colors.pinkAccent,
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          backgroundColor: Colors.pinkAccent,
        ),
      );
    } catch (e) {
      debugPrint('저장 실패: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('저장 실패 🥲'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // 화면 하단에서 스티커 목록이 올라오는 시트(BottomSheet)
  void _showStickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      builder: (context) {
        return SizedBox(
          height: 150,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _availableStickers.map((sticker) {
              return GestureDetector(
                onTap: () {
                  setState(() {
                    // 화면 중앙쯤에 새 스티커 추가
                    _stickers.add(StickerData(sticker, const Offset(150, 300)));
                  });
                  Navigator.pop(context); // 시트 닫기
                },
                child: Text(sticker, style: const TextStyle(fontSize: 40)),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('꾸미기', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // 핫핑크 저장(Save) 버튼
          Padding(
            padding: const EdgeInsets.only(right: 16.0, top: 8.0, bottom: 8.0),
            child: ElevatedButton(
              onPressed: _saveToGallery,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pinkAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'Save',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Column(
        children: [
          Expanded(
            // 이 RepaintBoundary 안에 있는 모든 것(사진+그림+스티커+워터마크)이 한 장의 사진으로 저장됩니다.
            child: RepaintBoundary(
              key: _editGlobalKey,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Layer 1: 카메라에서 찍힌 사진 (Base)
                  Image.memory(widget.capturedImage, fit: BoxFit.cover),

                  // Layer 2: 손가락으로 그리는 그림 층 (Drawing)
                  GestureDetector(
                    onPanStart: (details) {
                      setState(() {
                        _currentLine = [details.localPosition];
                        _lines.add(DrawnLine(_currentLine, _selectedColor));
                      });
                    },
                    onPanUpdate: (details) {
                      setState(() {
                        _currentLine.add(details.localPosition);
                      });
                    },
                    child: CustomPaint(
                      painter: DrawingPainter(lines: _lines),
                      size: Size.infinite,
                    ),
                  ),

                  // Layer 3: 스티커 층 (Sticker) - 터치해서 위치 이동 가능
                  ..._stickers.map((sticker) {
                    return Positioned(
                      left: sticker.position.dx,
                      top: sticker.position.dy,
                      child: GestureDetector(
                        onPanUpdate: (details) {
                          setState(() {
                            sticker.position += details.delta;
                          });
                        },
                        child: Text(
                          sticker.text,
                          style: const TextStyle(
                            fontSize: 60,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    );
                  }).toList(),

                  // Layer 4: ARlens 레트로 워터마크
                  const Positioned(
                    bottom: 20,
                    right: 20,
                    child: Text(
                      'ARlens',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        shadows: [
                          BoxShadow(
                            color: Colors.pinkAccent,
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 하단 편집 툴바
          Container(
            height: 80,
            color: Colors.black87,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 1. 스티커 추가 버튼
                IconButton(
                  icon: const Icon(
                    Icons.emoji_emotions,
                    color: Colors.blueAccent,
                    size: 32,
                  ),
                  onPressed: _showStickerSheet,
                ),
                // 2. 펜 색상 선택기
                Row(
                  children: _penColors.map((color) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedColor = color;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _selectedColor == color
                                ? Colors.white
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                // 3. 전체 지우기 버튼
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.pinkAccent,
                    size: 32,
                  ),
                  onPressed: () {
                    setState(() {
                      _lines.clear();
                      _stickers.clear();
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 선을 부드럽게 그려주는 화가 역할 클래스
class DrawingPainter extends CustomPainter {
  final List<DrawnLine> lines;

  DrawingPainter({required this.lines});

  @override
  void paint(Canvas canvas, Size size) {
    for (var line in lines) {
      final paint = Paint()
        ..color = line.color
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 6.0
        ..style = PaintingStyle.stroke
        // 네온 글로우 효과 추가
        ..maskFilter = MaskFilter.blur(BlurStyle.solid, 3.0);

      final path = Path();
      if (line.points.isNotEmpty) {
        path.moveTo(line.points.first.dx, line.points.first.dy);
        for (int i = 1; i < line.points.length; i++) {
          path.lineTo(line.points[i].dx, line.points[i].dy);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

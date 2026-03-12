import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/lens_provider.dart';

class CameraScreen extends StatelessWidget {
  const CameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // 실제 카메라 화면처럼 보이도록 배경을 검은색으로 설정
      appBar: AppBar(
        title: const Text(
          'ARlens',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent, // 투명한 상단바
        elevation: 0,
      ),
      body: Stack(
        children: [
          // 카메라 프리뷰가 들어갈 자리 (임시)
          const Center(
            child: Text(
              '📸 카메라 화면 (임시)',
              style: TextStyle(color: Colors.white54, fontSize: 24),
            ),
          ),

          // 하단 렌즈 슬라이더 영역
          Positioned(
            bottom: 40, // 화면 맨 아래에서 살짝 위로 띄움
            left: 0,
            right: 0,
            child: SizedBox(
              height: 100, // 슬라이더의 높이 (렌즈 썸네일 크기 고려)
              // Consumer를 통해 렌즈 데이터(LensProvider)를 실시간으로 가져옵니다.
              child: Consumer<LensProvider>(
                builder: (context, lensProvider, child) {
                  final lenses = lensProvider.lenses; // 전체 렌즈 목록

                  // 좌우로 스크롤 가능한 리스트
                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: lenses.length,
                    itemBuilder: (context, index) {
                      final lens = lenses[index];
                      // 현재 선택된 렌즈인지 확인
                      final isSelected =
                          lensProvider.selectedLens?.id == lens.id;

                      // 썸네일을 터치할 수 있도록 GestureDetector 사용
                      return GestureDetector(
                        onTap: () {
                          // 터치 시 해당 렌즈 선택 상태로 변경
                          lensProvider.selectLens(lens);
                        },
                        child: Container(
                          width: 80, // 썸네일 너비
                          margin: const EdgeInsets.symmetric(
                            horizontal: 10,
                          ), // 렌즈 사이 간격
                          decoration: BoxDecoration(
                            shape: BoxShape.circle, // 동그란 모양
                            // 선택된 렌즈에만 핫핑크 네온 글로우(Y2K 감성) 효과 켜기
                            boxShadow: isSelected
                                ? [
                                    const BoxShadow(
                                      color: Colors.pinkAccent, // 핫핑크 색상
                                      blurRadius: 15, // 네온이 퍼지는 정도
                                      spreadRadius: 5, // 네온이 뻗어나가는 크기
                                    ),
                                  ]
                                : [], // 선택 안 되면 그림자 없음
                            // 선택 시 테두리 색상도 변경
                            border: Border.all(
                              color: isSelected
                                  ? Colors.pinkAccent
                                  : Colors.grey.shade800,
                              width: isSelected ? 3 : 2,
                            ),
                            // 인터넷 이미지(임시 URL) 불러오기
                            image: DecorationImage(
                              image: NetworkImage(lens.thumbnailUrl),
                              fit: BoxFit.cover, // 사진이 동그라미에 꽉 차게
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

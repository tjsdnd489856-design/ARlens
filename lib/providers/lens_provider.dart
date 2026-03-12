import 'package:flutter/material.dart';
import '../models/lens_model.dart';

class LensProvider extends ChangeNotifier {
  // Y2K 컨셉에 맞는 더미 렌즈 데이터 3가지를 미리 등록해둡니다.
  final List<Lens> _lenses = [
    Lens(
      id: 'lens_1',
      name: '체리밤 핑크',
      description: '통통 튀는 핫핑크 Y2K 감성 필터',
      tags: ['Y2K', 'Pink', 'Retro'],
      thumbnailUrl:
          'https://via.placeholder.com/150/FF1493/FFFFFF?text=Cherry', // 임시 썸네일 이미지
      arTextureUrl: '',
    ),
    Lens(
      id: 'lens_2',
      name: '네온 블루',
      description: '사이버펑크 느낌의 몽환적인 파란색 필터',
      tags: ['Neon', 'Blue', 'Cyberpunk'],
      thumbnailUrl: 'https://via.placeholder.com/150/0000FF/FFFFFF?text=Neon',
      arTextureUrl: '',
    ),
    Lens(
      id: 'lens_3',
      name: '사이버 그레이',
      description: '세련된 메탈릭 그레이 색상의 필터',
      tags: ['Metallic', 'Gray', 'Chic'],
      thumbnailUrl: 'https://via.placeholder.com/150/808080/FFFFFF?text=Cyber',
      arTextureUrl: '',
    ),
  ];

  // 사용자가 선택한 렌즈를 담아둘 빈 공간 (아직 아무것도 선택하지 않았으므로 null)
  Lens? _selectedLens;

  // 외부(화면)에서 이 데이터를 안전하게 가져다 쓸 수 있도록 열어둡니다.
  List<Lens> get lenses => _lenses;
  Lens? get selectedLens => _selectedLens;

  // 사용자가 특정 렌즈를 터치했을 때 실행될 기능
  void selectLens(Lens lens) {
    _selectedLens = lens;
    notifyListeners(); // 렌즈가 바뀌었으니 화면을 다시 그리라고 앱에 알려줍니다.
  }
}

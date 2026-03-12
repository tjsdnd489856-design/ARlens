import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/lens_model.dart';

class LensProvider extends ChangeNotifier {
  List<Lens> _lenses = [];
  Lens? _selectedLens;
  bool _isLoading = false; // 데이터를 가져오는 중인지 확인하는 상태값

  // 외부에서 읽을 수 있도록 열어둡니다.
  List<Lens> get lenses => _lenses;
  Lens? get selectedLens => _selectedLens;
  bool get isLoading => _isLoading;

  // Provider가 처음 만들어질 때(앱 켜질 때) 자동으로 데이터를 가져오게 합니다.
  LensProvider() {
    fetchLensesFromFirebase();
  }

  // Firestore 데이터베이스에서 렌즈 정보들을 가져오는 비동기 함수
  Future<void> fetchLensesFromFirebase() async {
    _isLoading = true;
    notifyListeners(); // 로딩 시작을 화면에 알립니다.

    try {
      // 파이어베이스의 'Lenses' 컬렉션(폴더)에 접근합니다.
      final snapshot = await FirebaseFirestore.instance
          .collection('Lenses')
          .get();

      // 가져온 문서(Document)들을 하나씩 꺼내서 우리가 만든 Lens 객체로 조립합니다.
      _lenses = snapshot.docs.map((doc) {
        final data = doc.data();
        // 만약 문서 자체에 id가 없다면 문서의 고유 ID를 넣어줍니다.
        data['id'] = doc.id;
        return Lens.fromJson(data);
      }).toList();

      debugPrint('Firestore 렌즈 데이터 로딩 완료: ${_lenses.length}개');
    } catch (e) {
      // 서버 연결 실패나 에러가 나면 안전하게 빈 리스트로 둡니다.
      debugPrint('Firestore 렌즈 가져오기 에러: $e');
      _lenses = [];
    } finally {
      // 로딩이 끝났으므로 상태를 변경하고 화면을 다시 그리라고 알려줍니다.
      _isLoading = false;
      notifyListeners();
    }
  }

  // 사용자가 특정 렌즈를 터치했을 때 실행될 기능
  void selectLens(Lens lens) {
    _selectedLens = lens;
    notifyListeners();
  }
}

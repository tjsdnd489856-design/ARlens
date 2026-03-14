import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connectivity_provider.dart';

class GlobalNetworkOverlay {
  static OverlayEntry? _entry;

  /// [The Final One] 최상위 전역 오버레이로 네트워크 상태 표시
  static void show(BuildContext context) {
    if (_entry != null) return;

    _entry = OverlayEntry(
      builder: (context) => Consumer<ConnectivityProvider>(
        builder: (context, connectivity, _) {
          if (!connectivity.isOffline) return const SizedBox.shrink();
          
          return Positioned(
            top: 0, left: 0, right: 0,
            child: Material(
              color: Colors.redAccent.withOpacity(0.95),
              elevation: 10,
              child: SafeArea(
                bottom: false,
                child: Container(
                  height: 36,
                  alignment: Alignment.center,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 10),
                      Text(
                        '네트워크 연결 확인 중...',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    Overlay.of(context).insert(_entry!);
  }

  static void hide() {
    _entry?.remove();
    _entry = null;
  }
}

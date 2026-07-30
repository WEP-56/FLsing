import 'dart:async';

import 'package:flutter/material.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

OverlayEntry? _currentToast;
Timer? _toastTimer;

/// 在根 Overlay 顶部显示提示，位于所有对话框 / 底部面板之上。
void showAppMessage(String message) {
  final overlay = appNavigatorKey.currentState?.overlay;
  if (overlay == null) return;
  _toastTimer?.cancel();
  _currentToast?.remove();
  final entry = OverlayEntry(
    builder: (context) => Positioned(
      top: MediaQuery.paddingOf(context).top + 12,
      left: 20,
      right: 20,
      child: IgnorePointer(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xF0303030),
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ),
      ),
    ),
  );
  _currentToast = entry;
  overlay.insert(entry);
  _toastTimer = Timer(const Duration(seconds: 3), () {
    if (_currentToast == entry) {
      entry.remove();
      _currentToast = null;
    }
  });
}

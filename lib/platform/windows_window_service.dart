// ignore_for_file: deprecated_member_use
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:screen_retriever/legacy.dart';
import 'package:window_manager/legacy.dart';

import '../core/models/app_settings.dart';

/// Abstração sobre window_manager: posição, pin (sempre no topo), resize e persistência.
class WindowsWindowService with WindowListener {
  static const defaultSize = Size(340, 240);
  static const minSize = Size(260, 180);
  static const maxSize = Size(900, 700);
  static const _margin = 12.0;

  AppSettings? _s;
  VoidCallback? onGeometryChanged;
  Future<void> Function()? onCloseRequested;
  ValueChanged<bool>? onFocusChanged;

  Future<void> init(AppSettings s) async {
    _s = s;
    await windowManager.ensureInitialized();
    final size = Size(
      (s.windowWidth ?? defaultSize.width).clamp(minSize.width, maxSize.width),
      (s.windowHeight ?? defaultSize.height).clamp(minSize.height, maxSize.height),
    );
    final pos = await _initialPosition(s, size);

    final options = WindowOptions(
      size: size,
      minimumSize: minSize,
      maximumSize: maxSize,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
      skipTaskbar: false,
      alwaysOnTop: s.alwaysOnTop,
      title: 'ASCII Fish Pet',
    );
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setPosition(pos);
      await windowManager.show();
      await windowManager.focus();
    });
  }

  Future<Offset> _initialPosition(AppSettings s, Size size) async {
    if (s.windowX != null && s.windowY != null) {
      final saved = Offset(s.windowX!, s.windowY!);
      final displays = await screenRetriever.getAllDisplays();
      final onScreen = displays.any((d) {
        final p = d.visiblePosition ?? Offset.zero;
        final sz = d.visibleSize ?? d.size;
        return Rect.fromLTWH(p.dx, p.dy, sz.width, sz.height).contains(saved + const Offset(20, 20));
      });
      if (onScreen) return saved;
    }
    return _corner(size);
  }

  Future<Offset> _corner(Size size) async {
    final d = await screenRetriever.getPrimaryDisplay();
    final p = d.visiblePosition ?? Offset.zero;
    final sz = d.visibleSize ?? d.size;
    return Offset(p.dx + sz.width - size.width - _margin, p.dy + sz.height - size.height - _margin);
  }

  Future<void> setAlwaysOnTop(bool v) => windowManager.setAlwaysOnTop(v);

  Future<void> snapToCorner() async {
    final size = await windowManager.getSize();
    await windowManager.setPosition(await _corner(size));
    await _store();
  }

  Future<void> minimize() => windowManager.minimize();
  Future<void> close() => windowManager.close();

  Future<void> _store() async {
    final s = _s;
    if (s == null) return;
    final p = await windowManager.getPosition();
    final sz = await windowManager.getSize();
    s.windowX = p.dx;
    s.windowY = p.dy;
    s.windowWidth = sz.width;
    s.windowHeight = sz.height;
    onGeometryChanged?.call();
  }

  @override
  void onWindowMoved() => _store();

  @override
  void onWindowResized() => _store();

  @override
  void onWindowFocus() => onFocusChanged?.call(true);

  @override
  void onWindowBlur() => onFocusChanged?.call(false);

  @override
  Future<void> onWindowClose() async {
    await onCloseRequested?.call();
    await windowManager.destroy();
  }
}

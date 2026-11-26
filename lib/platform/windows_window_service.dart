// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:screen_retriever/legacy.dart';
import 'package:window_manager/legacy.dart';

import '../core/models/app_settings.dart';
import 'desktop_layer.dart';

/// Janela transparente em faixa, encaixada na base da área útil da tela (logo acima da taskbar).
class WindowsWindowService with WindowListener {
  static const minHeight = 120.0;
  static const defaultHeight = 200.0;

  AppSettings? _s;
  VoidCallback? onGeometryChanged;
  Future<void> Function()? onCloseRequested;
  ValueChanged<bool>? onFocusChanged;

  /// Posição/tamanho atuais em pixels lógicos (usados pelo click-through).
  Offset origin = Offset.zero;
  Size size = const Size(1200, defaultHeight);
  bool hidden = false;
  bool quitting = false;

  Future<Rect> _workArea() async {
    final d = await screenRetriever.getPrimaryDisplay();
    final p = d.visiblePosition ?? Offset.zero;
    final sz = d.visibleSize ?? d.size;
    return p & sz;
  }

  Future<void> init(AppSettings s) async {
    _s = s;
    await windowManager.ensureInitialized();
    final area = await _workArea();
    final h = (s.windowHeight ?? defaultHeight).clamp(minHeight, area.height * 0.8);
    origin = Offset(area.left, area.bottom - h);
    size = Size(area.width, h);

    final options = WindowOptions(
      size: size,
      minimumSize: const Size(400, minHeight),
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
      backgroundColor: const Color(0x00000000),
      skipTaskbar: true, // só aparece na bandeja (ícones ocultos)
      alwaysOnTop: s.alwaysOnTop,
      title: 'ASCII Fish Pet',
    );
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setBackgroundColor(const Color(0x00000000));
      try {
        await windowManager.setHasShadow(false);
      } catch (_) {}
      await dock();
      await windowManager.show();
      await applyZOrder();
      _watchDesktopPeek();
    });
  }

  /// Encaixa a faixa na base da área útil, com a altura pedida (ou a salva).
  Future<void> dock({double? height}) async {
    final area = await _workArea();
    final h = (height ?? _s?.windowHeight ?? defaultHeight).clamp(minHeight, area.height * 0.9);
    origin = Offset(area.left, area.bottom - h);
    size = Size(area.width, h);
    await windowManager.setBounds(null, position: origin, size: size);
  }

  /// Pin = sempre no topo. Modo widget (padrão) = camada de desktop: sob os apps, sobre o papel de parede.
  /// Senão, janela normal.
  Future<void> applyZOrder() async {
    final s = _s!;
    await windowManager.setAlwaysOnTop(s.alwaysOnTop);
    if (!s.alwaysOnTop && s.widgetMode) DesktopLayer.sendAboveDesktop();
  }

  Timer? _layerTimer;
  bool _peeking = false;

  /// Acompanha o Win+D: enquanto o desktop está à mostra o widget sobe; ao voltar, desce de novo.
  void _watchDesktopPeek() {
    _layerTimer ??= Timer.periodic(const Duration(milliseconds: 300), (_) {
      final s = _s;
      if (s == null || hidden || s.alwaysOnTop || !s.widgetMode) {
        if (_peeking && s != null && !s.alwaysOnTop) windowManager.setAlwaysOnTop(false);
        _peeking = false;
        return;
      }
      final raised = DesktopLayer.desktopRaised();
      if (raised && !_peeking) {
        _peeking = true;
        windowManager.setAlwaysOnTop(true); // o Progman fica topmost durante o Win+D
      } else if (!raised && _peeking) {
        _peeking = false;
        windowManager.setAlwaysOnTop(false).then((_) => DesktopLayer.sendAboveDesktop());
      }
    });
  }

  Future<void> setWidgetMode(bool v) async {
    _s!.widgetMode = v;
    await applyZOrder();
  }

  Future<void> setAlwaysOnTop(bool v) async {
    _s!.alwaysOnTop = v;
    await applyZOrder();
  }

  Future<void> setIgnoreMouse(bool ignore) => windowManager.setIgnoreMouseEvents(ignore);

  Future<void> hideToTray() async {
    hidden = true;
    await windowManager.hide();
  }

  Future<void> showRaised() async {
    hidden = false;
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> quit() async {
    quitting = true;
    await windowManager.close();
  }

  @override
  void onWindowFocus() => onFocusChanged?.call(true);

  @override
  void onWindowBlur() {
    onFocusChanged?.call(false);
    final s = _s;
    if (s != null && !hidden) applyZOrder(); // ao perder o foco volta para a camada de desktop
  }

  @override
  Future<void> onWindowClose() async {
    if (!quitting) {
      await hideToTray();
      return;
    }
    await onCloseRequested?.call();
    await windowManager.destroy();
  }
}
